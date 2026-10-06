  const {setGlobalOptions} = require("firebase-functions/v2/options");
    const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
    const logger = require("firebase-functions/logger");
    const admin = require('firebase-admin');
    const {getFirestore} = require('firebase-admin/firestore');

    admin.initializeApp();

    // Named Firestore databases
    const prodDb = getFirestore('prod');
    const stageDb = getFirestore('stage');

    // Configurar opciones globales
    setGlobalOptions({
      maxInstances: 10,
      region: 'us-east1'
    });

  /**
   * Calcula la distribucion de recompensas.
   *
   * Modo apuesta  (diamantes): casa cobra 10% del pot -> ganador recibe 90% del pot.
   * Modo diversion (monedas) : casa cobra 30% del pot -> ganador recibe 70% del pot.
   *
   * Empate apuesta  : cada jugador recupera 90% de su apuesta (casa: 10%).
   * Empate diversion: cada jugador recupera 15% de su cuota   (casa: 70%).
   *
   * Se usa Math.floor para que cualquier fraccion sobrante siempre vaya a la casa.
   *
   * @param {number}  quotaAmount - Apuesta de cada jugador (pot total = quotaAmount x 2).
   * @param {boolean} isBetMode   - true = modo apuesta con diamantes.
   */
  function calcDistribution(quotaAmount, isBetMode) {
    const pot = quotaAmount * 2;
    if (isBetMode) {
      const winnerPrize         = Math.floor(pot * 0.90);
      const drawReturn          = Math.floor(quotaAmount * 0.90);
      const houseCommissionWin  = pot - winnerPrize;
      const houseCommissionDraw = pot - (drawReturn * 2);
      return { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw };
    } else {
      const winnerPrize         = Math.floor(pot * 0.70);
      const drawReturn          = Math.floor(quotaAmount * 0.15);
      const houseCommissionWin  = pot - winnerPrize;
      const houseCommissionDraw = pot - (drawReturn * 2);
      return { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw };
    }
  }

  function getTodayKey() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  }

  async function readSecurityDocs(db, transaction) {
    const todayKey = getTodayKey();
    const configRef = db.collection('system_config').doc('betting_limits');
    const dailyPayoutRef = db.collection('system_config').doc(`daily_payouts_${todayKey}`);
    const configDoc = await transaction.get(configRef);
    const dailyPayoutDoc = await transaction.get(dailyPayoutRef);
    return {
      config: configDoc.exists ? configDoc.data() : {},
      dailyPayout: dailyPayoutDoc.exists ? dailyPayoutDoc.data() : null,
      configRef, dailyPayoutRef, todayKey,
    };
  }

  function writePayoutTracking(transaction, security, rewardAmount, gameId) {
    const { dailyPayout, dailyPayoutRef, todayKey, config } = security;
    const currentTotal = dailyPayout ? (dailyPayout.totalPaidOut || 0) : 0;
    const newTotal = currentTotal + rewardAmount;
    const maxDaily = config.maxDailyPayout || 500000;

    if (dailyPayout) {
      transaction.update(dailyPayoutRef, {
        totalPaidOut: admin.firestore.FieldValue.increment(rewardAmount),
        lastGameId: gameId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.set(dailyPayoutRef, {
        date: todayKey,
        totalPaidOut: rewardAmount,
        lastGameId: gameId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (newTotal > maxDaily) {
      transaction.update(security.configRef, { bettingEnabled: false });
    }
  }

  async function logAudit(db, entry) {
    try {
      await db.collection('_audit_log').add({
        ...entry,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('Audit log error:', e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY: generates all game functions for a given Firestore database
  // ═══════════════════════════════════════════════════════════════════════════
  function createGameFunctions(db, databaseId, suffix) {
    const fns = {};

    // ─── Notification: game invitation ──────────────────────────────
    fns[`sendGameInvitationNotification${suffix}`] = onDocumentCreated(
      {
        document: 'game_invitations/{invitationId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const invitation = event.data?.data();
        const invitationId = event.params.invitationId;

        if (!invitation) {
          console.log('No invitation data found');
          return null;
        }

        try {
          const tokenDoc = await db
            .collection('user_tokens')
            .doc(invitation.toUserId)
            .get();

          if (!tokenDoc.exists) {
            console.log('No token found for user:', invitation.toUserId);
            return null;
          }

          const userToken = tokenDoc.data().token;

          const message = {
            token: userToken,
            notification: {
              title: 'Nueva invitacion de juego',
              body: `${invitation.fromUserName} te invita a jugar ${invitation.gameType}`,
            },
            data: {
              type: 'game_invitation',
              invitationId: invitationId,
              gameType: invitation.gameType,
              fromUserName: invitation.fromUserName,
            },
            android: {
              priority: 'high',
              notification: {
                icon: 'ic_notification',
                color: '#EC7A34',
                sound: 'default',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          };

          const response = await admin.messaging().send(message);
          console.log('Notification sent successfully:', response);

          return response;
        } catch (error) {
          console.error('Error sending notification:', error);
          return null;
        }
      }
    );

    // ─── Notification: game move (chess) ────────────────────────────
    fns[`sendGameMoveNotification${suffix}`] = onDocumentUpdated(
      {
        document: 'multiplayer_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const before = event.data?.before.data();
        const after = event.data?.after.data();
        const gameId = event.params.gameId;

        if (!before || !after) {
          console.log('No game data found');
          return null;
        }

        if (before.currentTurn === after.currentTurn) {
          return null;
        }

        try {
          const currentPlayerId = after.currentTurn === 'host' ? after.hostId : after.guestId;
          const opponentName = after.currentTurn === 'host' ? after.guestName : after.hostName;

          if (!currentPlayerId) return null;

          const tokenDoc = await db
            .collection('user_tokens')
            .doc(currentPlayerId)
            .get();

          if (!tokenDoc.exists) {
            console.log('No token found for user:', currentPlayerId);
            return null;
          }

          const userToken = tokenDoc.data().token;

          const message = {
            token: userToken,
            notification: {
              title: 'Tu turno',
              body: `${opponentName} ha movido. Es tu turno!`,
            },
            data: {
              type: 'game_move',
              gameId: gameId,
              opponentName: opponentName,
              moveNotation: after.lastMoveNotation || '',
            },
            android: {
              priority: 'high',
              notification: {
                icon: 'ic_notification',
                color: '#EC7A34',
                sound: 'default',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          };

          const response = await admin.messaging().send(message);
          console.log('Move notification sent:', response);

          return response;
        } catch (error) {
          console.error('Error sending move notification:', error);
          return null;
        }
      }
    );

    // ─── Notification: game finished (chess) ────────────────────────
    fns[`sendGameFinishedNotification${suffix}`] = onDocumentUpdated(
      {
        document: 'multiplayer_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const before = event.data?.before.data();
        const after = event.data?.after.data();
        const gameId = event.params.gameId;

        if (!before || !after) {
          console.log('No game data found');
          return null;
        }

        if (before.status === 'finished' || after.status !== 'finished') {
          return null;
        }

        try {
          const players = [
            { id: after.hostId, name: after.hostName },
            { id: after.guestId, name: after.guestName }
          ];

          const promises = players.map(async (player) => {
            if (!player.id) return null;

            const tokenDoc = await db
              .collection('user_tokens')
              .doc(player.id)
              .get();

            if (!tokenDoc.exists) return null;

            const userToken = tokenDoc.data().token;

            let title, body;
            if (after.result === 'draw') {
              title = 'Juego terminado';
              body = 'La partida termino en empate';
            } else if (after.winnerId === player.id) {
              title = 'Felicidades!';
              body = 'Has ganado la partida!';
            } else {
              title = 'Juego terminado';
              body = 'Has perdido la partida';
            }

            const message = {
              token: userToken,
              notification: { title, body },
              data: {
                type: 'game_finished',
                gameId: gameId,
                result: after.result,
                winnerId: after.winnerId || '',
              },
            };

            return admin.messaging().send(message);
          });

          await Promise.all(promises);
          console.log('Game finished notifications sent');

          return null;
        } catch (error) {
          console.error('Error sending game finished notifications:', error);
          return null;
        }
      }
    );

    // ─── Chess: distribute rewards (non-online) ────────────────────
    fns[`distributeGameRewards${suffix}`] = onDocumentUpdated(
      {
        document: 'multiplayer_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const gameId = event.params.gameId;
        const beforeData = event.data?.before.data();
        const afterData = event.data?.after.data();

        console.log(`\n[${gameId}] === INICIO distributeGameRewards (${databaseId}) ===`);
        console.log(`Status: "${beforeData?.status}" -> "${afterData?.status}"`);

        if (!beforeData || !afterData) return null;

        if (afterData.gameSettings?.isOnlineMatchmaking === true && afterData.currencyType === 'diamonds') {
          console.log(`[${gameId}] Online matchmaking diamonds -> manejado por distributeOnlineBetGameRewards (SALIENDO)`);
          return null;
        }

        const gameJustFinished = beforeData.status !== 'finished' && afterData.status === 'finished';
        const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

        if (!gameJustFinished && !gameJustAbandoned) return null;
        if (afterData.rewardsDistributed === true) return null;
        if (afterData.quotasCollected !== true) return null;

        const winnerId = afterData.winnerId;
        const hostId = afterData.hostId;
        const guestId = afterData.guestId;
        const totalPot = afterData.totalPot || 0;
        const currencyType = afterData.currencyType || 'coins';
        const result = afterData.result;
        const abandonedBy = afterData.abandonedBy;
        const isBetMode = currencyType === 'diamonds' && (afterData.betAmount || 0) > 0;

        if (!guestId || totalPot === 0) return null;

        let auditData = { gameId, databaseId, function: 'distributeGameRewards', currencyType, isBetMode };

        try {
          await db.runTransaction(async (transaction) => {
            const gameRef = db.collection('multiplayer_games').doc(gameId);
            const hostRef = db.collection('users').doc(hostId);
            const guestRef = db.collection('users').doc(guestId);

            const security = isBetMode ? await readSecurityDocs(db, transaction) : null;

            const hostDoc  = await transaction.get(hostRef);
            const guestDoc = await transaction.get(guestRef);
            const gameDoc  = await transaction.get(gameRef);

            if (!hostDoc.exists || !guestDoc.exists) throw new Error('Usuarios no encontrados');

            const currentGameData = gameDoc.data();
            if (currentGameData && currentGameData.rewardsDistributed === true) return;

            const hostData  = hostDoc.data();
            const guestData = guestDoc.data();

            if (isBetMode && security) {
              if (security.config.bettingEnabled === false) {
                transaction.update(gameRef, {
                  rewardsDistributed: true, distributionBlocked: 'betting_disabled',
                  rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                auditData.blocked = 'betting_disabled';
                return;
              }
              if (hostData.suspended === true || guestData.suspended === true) {
                transaction.update(gameRef, {
                  rewardsDistributed: true, distributionBlocked: 'user_suspended',
                  rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                auditData.blocked = 'user_suspended';
                return;
              }
            }

            const quotaAmount = totalPot / 2;
            const { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw } =
              calcDistribution(quotaAmount, isBetMode);

            let hostReward  = 0;
            let guestReward = 0;
            let actualHouseCommission = 0;

            if (gameJustAbandoned) {
              if (abandonedBy === hostId) {
                guestReward = winnerPrize;
              } else if (abandonedBy === guestId) {
                hostReward = winnerPrize;
              }
              actualHouseCommission = totalPot - hostReward - guestReward;
            } else {
              if (result === 'draw') {
                hostReward  = drawReturn;
                guestReward = drawReturn;
                actualHouseCommission = houseCommissionDraw;
              } else if (winnerId === hostId) {
                hostReward  = winnerPrize;
                actualHouseCommission = houseCommissionWin;
              } else if (winnerId === guestId) {
                guestReward = winnerPrize;
                actualHouseCommission = houseCommissionWin;
              }
            }

            const totalDistributed = hostReward + guestReward + actualHouseCommission;
            if (totalDistributed !== totalPot) {
              throw new Error(`MATH ERROR: totalPot(${totalPot}) != distributed(${totalDistributed})`);
            }

            if (currencyType === 'coins') {
              transaction.update(hostRef,  { coins: (hostData.coins || 0) + hostReward });
              transaction.update(guestRef, { coins: (guestData.coins || 0) + guestReward });
            } else {
              const hostNetGain  = hostReward  - quotaAmount;
              const guestNetGain = guestReward - quotaAmount;
              transaction.update(hostRef,  { diamonds: (hostData.diamonds || 0) + hostReward,  diamondsEarned: (hostData.diamondsEarned  || 0) + Math.max(0, hostNetGain)  });
              transaction.update(guestRef, { diamonds: (guestData.diamonds || 0) + guestReward, diamondsEarned: (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain) });
            }

            transaction.update(gameRef, {
              rewardsDistributed: true,
              rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              distribution: {
                hostReward, guestReward,
                houseCommission: actualHouseCommission,
                currencyType, isBetMode,
                commissionRate: isBetMode ? 0.10 : 0.30,
                reason: gameJustAbandoned ? 'abandoned' : result,
                abandonedBy: abandonedBy || null,
              },
            });

            const totalPlayerReward = hostReward + guestReward;
            if (isBetMode && security) {
              writePayoutTracking(transaction, security, totalPlayerReward, gameId);
            }
            auditData = { ...auditData, hostReward, guestReward, houseCommission: actualHouseCommission, winnerId };
          });

          await logAudit(db, auditData);
          return null;
        } catch (error) {
          console.error(`[${gameId}] ERROR en distributeGameRewards:`, error);
          throw error;
        }
      }
    );

    // ─── Chess: distribute online bet rewards ──────────────────────
    fns[`distributeOnlineBetGameRewards${suffix}`] = onDocumentUpdated(
      {
        document: 'multiplayer_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const gameId = event.params.gameId;
        const beforeData = event.data?.before.data();
        const afterData = event.data?.after.data();

        if (!beforeData || !afterData) return null;

        if (afterData.currencyType !== 'diamonds' || !afterData.gameSettings?.isOnlineMatchmaking) return null;

        const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
        const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

        if (!gameJustFinished && !gameJustAbandoned) return null;
        if (afterData.rewardsDistributed === true) return null;
        if (afterData.quotasCollected !== true) return null;

        const hostId      = afterData.hostId;
        const guestId     = afterData.guestId;
        const totalPot    = afterData.totalPot || 0;
        const winnerId    = afterData.winnerId;
        const result      = afterData.result;
        const abandonedBy = afterData.abandonedBy;

        if (!hostId || !guestId || totalPot === 0) return null;

        let auditData = { gameId, databaseId, function: 'distributeOnlineBetGameRewards' };

        try {
          await db.runTransaction(async (transaction) => {
            const gameRef  = db.collection('multiplayer_games').doc(gameId);
            const hostRef  = db.collection('users').doc(hostId);
            const guestRef = db.collection('users').doc(guestId);

            const security = await readSecurityDocs(db, transaction);
            const gameDoc  = await transaction.get(gameRef);
            const hostDoc  = await transaction.get(hostRef);
            const guestDoc = await transaction.get(guestRef);

            const currentGameData = gameDoc.data();
            if (currentGameData?.rewardsDistributed === true) return;

            if (security.config.bettingEnabled === false) {
              transaction.update(gameRef, {
                rewardsDistributed: true, distributionBlocked: 'betting_disabled',
                rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              auditData.blocked = 'betting_disabled';
              return;
            }

            const hostData = hostDoc.exists ? hostDoc.data() : {};
            const guestData = guestDoc.exists ? guestDoc.data() : {};
            if (hostData.suspended === true || guestData.suspended === true) {
              transaction.update(gameRef, {
                rewardsDistributed: true, distributionBlocked: 'user_suspended',
                rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              auditData.blocked = 'user_suspended';
              return;
            }

            const quotaAmount = totalPot / 2;
            const { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw } =
              calcDistribution(quotaAmount, true);

            let hostReward = 0;
            let guestReward = 0;
            let actualHouseCommission = 0;
            let distributionReason = '';

            if (gameJustAbandoned) {
              distributionReason = 'abandoned';
              if (abandonedBy === hostId) { guestReward = winnerPrize; }
              else if (abandonedBy === guestId) { hostReward = winnerPrize; }
              actualHouseCommission = totalPot - hostReward - guestReward;
            } else if (result === 'draw') {
              distributionReason = 'draw';
              hostReward  = drawReturn;
              guestReward = drawReturn;
              actualHouseCommission = houseCommissionDraw;
            } else if (winnerId === hostId) {
              distributionReason = 'host_won';
              hostReward = winnerPrize;
              actualHouseCommission = houseCommissionWin;
            } else if (winnerId === guestId) {
              distributionReason = 'guest_won';
              guestReward = winnerPrize;
              actualHouseCommission = houseCommissionWin;
            }

            const totalDistributed = hostReward + guestReward + actualHouseCommission;
            if (totalDistributed !== totalPot) {
              throw new Error(`MATH ERROR: totalPot(${totalPot}) != distributed(${totalDistributed})`);
            }

            if (hostReward > 0) {
              transaction.update(hostRef, { diamondsEarned: admin.firestore.FieldValue.increment(hostReward) });
            }
            if (guestReward > 0) {
              transaction.update(guestRef, { diamondsEarned: admin.firestore.FieldValue.increment(guestReward) });
            }

            const hostNetGain  = hostReward  - quotaAmount;
            const guestNetGain = guestReward - quotaAmount;

            transaction.update(gameRef, {
              rewardsDistributed: true,
              rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              distribution: {
                hostReward, guestReward,
                houseCommission: actualHouseCommission,
                totalPot, betAmount: quotaAmount,
                currencyType: 'diamonds', isBetMode: true,
                commissionRate: 0.10,
                reason: distributionReason,
                abandonedBy: abandonedBy || null,
                hostNetGain, guestNetGain,
              },
            });

            const totalPlayerReward = hostReward + guestReward;
            writePayoutTracking(transaction, security, totalPlayerReward, gameId);
            auditData = { ...auditData, hostReward, guestReward, houseCommission: actualHouseCommission, winnerId };
          });

          await logAudit(db, auditData);
          return null;
        } catch (error) {
          console.error(`[${gameId}] ERROR en distributeOnlineBetGameRewards:`, error);
          throw error;
        }
      }
    );

    // ─── Ludo: distribute rewards ──────────────────────────────────
    fns[`distributeLudoGameRewards${suffix}`] = onDocumentUpdated(
      {
        document: 'ludo_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const gameId = event.params.gameId;
        const beforeData = event.data?.before.data();
        const afterData  = event.data?.after.data();

        if (!beforeData || !afterData) return null;

        const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
        const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

        if (!gameJustFinished && !gameJustAbandoned) return null;
        if (afterData.rewardsDistributed === true) return null;

        const betAmount    = afterData.betAmount || 0;
        const currencyType = afterData.currencyType || 'coins';
        if (betAmount === 0) return null;

        const hostId      = afterData.hostId;
        const winnerId    = afterData.winnerId;
        const abandonedBy = afterData.abandonedBy;

        const allSlotIds = [hostId, afterData.guest2Id, afterData.guest3Id, afterData.guest4Id];
        const realPlayerIds = allSlotIds.filter(id => id && !String(id).startsWith('bot_'));

        if (realPlayerIds.length < 2) return null;

        let auditData = { gameId, databaseId, function: 'distributeLudoGameRewards', currencyType };

        try {
          await db.runTransaction(async (transaction) => {
            const gameRef = db.collection('ludo_games').doc(gameId);
            const isCoins = currencyType === 'coins';
            const isBetMode = !isCoins && betAmount > 0;

            const security = isBetMode ? await readSecurityDocs(db, transaction) : null;
            const gameDoc = await transaction.get(gameRef);

            const playerDocs = {};
            if (isBetMode) {
              for (const pid of realPlayerIds) {
                playerDocs[pid] = { doc: await transaction.get(db.collection('users').doc(pid)) };
              }
            }

            const currentGameData = gameDoc.data();
            if (currentGameData && currentGameData.rewardsDistributed === true) return;
            if (currentGameData?.quotasCollected !== true) return;

            if (isBetMode && security) {
              if (security.config.bettingEnabled === false) {
                transaction.update(gameRef, {
                  rewardsDistributed: true, distributionBlocked: 'betting_disabled',
                  rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                auditData.blocked = 'betting_disabled';
                return;
              }
              const suspendedIds = realPlayerIds.filter(pid => playerDocs[pid]?.doc?.data()?.suspended === true);
              if (suspendedIds.length > 0) {
                transaction.update(gameRef, {
                  rewardsDistributed: true, distributionBlocked: 'user_suspended',
                  suspendedUsers: suspendedIds,
                  rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                auditData.blocked = 'user_suspended';
                return;
              }
            }

            const realPlayerCount = realPlayerIds.length;

            if (gameJustAbandoned) {
              const nonAbandoningIds = realPlayerIds.filter(id => id !== abandonedBy);
              if (nonAbandoningIds.length === 0) return;

              const totalRefund = betAmount * nonAbandoningIds.length;
              for (const playerId of nonAbandoningIds) {
                const playerRef = db.collection('users').doc(playerId);
                if (isCoins) {
                  transaction.update(playerRef, { coins: admin.firestore.FieldValue.increment(betAmount) });
                } else {
                  transaction.update(playerRef, { diamondsEarned: admin.firestore.FieldValue.increment(betAmount) });
                }
              }

              transaction.update(gameRef, {
                rewardsDistributed: true,
                rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                distribution: {
                  type: 'abandoned_refund', abandonedBy,
                  refundedPlayers: nonAbandoningIds, refundAmount: betAmount,
                  houseKeeps: betAmount, currencyType, isBetMode,
                },
              });

              if (isBetMode && security) {
                writePayoutTracking(transaction, security, totalRefund, gameId);
              }
              auditData = { ...auditData, type: 'abandoned_refund', refundAmount: betAmount };
              return;
            }

            const totalPot = currentGameData.totalPot || (betAmount * realPlayerCount);
            const commissionRate = isBetMode ? 0.10 : 0.30;
            const winnerPrize = Math.floor(totalPot * (1 - commissionRate));
            const houseCommission = totalPot - winnerPrize;

            if (!realPlayerIds.includes(winnerId)) return;

            const winnerRef = db.collection('users').doc(winnerId);
            const winnerNetGain = winnerPrize - betAmount;

            if (winnerPrize + houseCommission !== totalPot) {
              throw new Error(`[Ludo] MATH ERROR: totalPot(${totalPot}) != distributed(${winnerPrize + houseCommission})`);
            }

            if (isCoins) {
              transaction.update(winnerRef, { coins: admin.firestore.FieldValue.increment(winnerPrize) });
            } else {
              transaction.update(winnerRef, { diamondsEarned: admin.firestore.FieldValue.increment(winnerPrize) });
            }

            transaction.update(gameRef, {
              rewardsDistributed: true,
              rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              distribution: {
                winnerId, winnerPrize, houseCommission, totalPot, betAmount,
                realPlayerCount, currencyType, isBetMode, commissionRate,
                reason: 'win', winnerNetGain,
              },
            });

            if (isBetMode && security) {
              writePayoutTracking(transaction, security, winnerPrize, gameId);
            }
            auditData = { ...auditData, winnerId, winnerPrize, houseCommission, currencyType };
          });

          await logAudit(db, auditData);
          return null;
        } catch (error) {
          console.error(`[Ludo ${gameId}] ERROR:`, error);
          throw error;
        }
      }
    );

    // ─── Domino: distribute rewards ────────────────────────────────
    fns[`distributeDominoGameRewards${suffix}`] = onDocumentUpdated(
      {
        document: 'domino_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const gameId = event.params.gameId;
        const beforeData = event.data?.before.data();
        const afterData  = event.data?.after.data();

        if (!beforeData || !afterData) return null;

        const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
        const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

        if (!gameJustFinished && !gameJustAbandoned) return null;
        if (afterData.rewardsDistributed === true) return null;

        const betAmount    = afterData.betAmount || 0;
        const currencyType = afterData.currencyType || 'coins';
        if (betAmount === 0) return null;

        const hostId   = afterData.hostId;
        const guestId  = afterData.guestId;
        const guest2Id = afterData.guest2Id || null;
        const guest3Id = afterData.guest3Id || null;
        const winnerId = afterData.winnerId;
        const abandonedBy = afterData.abandonedBy;

        const allPlayerIds = [hostId, guestId, guest2Id, guest3Id].filter(id => !!id);
        const realPlayerIds = allPlayerIds.filter(id => !String(id).startsWith('bot_'));

        if (realPlayerIds.length === 0) return null;
        if (afterData.quotasCollected !== true) return null;

        let auditData = { gameId, databaseId, function: 'distributeDominoGameRewards', currencyType };

        try {
          await db.runTransaction(async (transaction) => {
            const gameRef = db.collection('domino_games').doc(gameId);
            const isCoins   = currencyType === 'coins';
            const isBetMode = !isCoins && betAmount > 0;

            const security = isBetMode ? await readSecurityDocs(db, transaction) : null;
            const gameDoc = await transaction.get(gameRef);

            const playerDocs = {};
            if (isBetMode) {
              for (const pid of realPlayerIds) {
                playerDocs[pid] = { doc: await transaction.get(db.collection('users').doc(pid)) };
              }
            }

            const currentGameData = gameDoc.data();

            if (currentGameData?.rewardsDistributed === true) return;
            if (currentGameData?.quotasCollected !== true) return;

            if (isBetMode && security) {
              if (security.config.bettingEnabled === false) {
                transaction.update(gameRef, {
                  rewardsDistributed: true, distributionBlocked: 'betting_disabled',
                  rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                auditData.blocked = 'betting_disabled';
                return;
              }
              const suspendedIds = realPlayerIds.filter(pid => playerDocs[pid]?.doc?.data()?.suspended === true);
              if (suspendedIds.length > 0) {
                transaction.update(gameRef, {
                  rewardsDistributed: true, distributionBlocked: 'user_suspended',
                  suspendedUsers: suspendedIds,
                  rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                auditData.blocked = 'user_suspended';
                return;
              }
            }

            const realPlayerCount = realPlayerIds.length;
            const totalPot  = currentGameData.totalPot || (betAmount * realPlayerCount);
            const commissionRate = isBetMode ? 0.10 : 0.30;
            const winnerPrize    = Math.floor(totalPot * (1 - commissionRate));
            const houseCommission = totalPot - winnerPrize;

            const effectiveWinnerId = gameJustAbandoned
              ? (currentGameData.winnerId || (abandonedBy === hostId ? guestId : hostId))
              : winnerId;

            if (!realPlayerIds.includes(effectiveWinnerId)) return;

            const winnerRef    = db.collection('users').doc(effectiveWinnerId);
            const winnerNetGain = winnerPrize - betAmount;

            if (isCoins) {
              transaction.update(winnerRef, { coins: admin.firestore.FieldValue.increment(winnerPrize) });
            } else {
              transaction.update(winnerRef, { diamondsEarned: admin.firestore.FieldValue.increment(winnerPrize) });
            }

            transaction.update(gameRef, {
              rewardsDistributed: true,
              rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              distribution: {
                winnerId: effectiveWinnerId, winnerPrize, houseCommission, totalPot, betAmount,
                currencyType, isBetMode, commissionRate,
                reason: gameJustAbandoned ? 'abandoned' : 'win', winnerNetGain,
              },
            });

            if (isBetMode && security) {
              writePayoutTracking(transaction, security, winnerPrize, gameId);
            }
            auditData = { ...auditData, winnerId: effectiveWinnerId, winnerPrize, houseCommission };
          });

          await logAudit(db, auditData);
          return null;
        } catch (error) {
          console.error(`[Domino ${gameId}] ERROR:`, error);
          throw error;
        }
      }
    );

    // ─── Domino Pase: distribute rewards ───────────────────────────
    fns[`distributeDominoPaseGameRewards${suffix}`] = onDocumentUpdated(
      {
        document: 'domino_pase_games/{gameId}',
        database: databaseId,
        region: 'us-east1',
      },
      async (event) => {
        const gameId = event.params.gameId;
        const beforeData = event.data?.before.data();
        const afterData  = event.data?.after.data();

        if (!beforeData || !afterData) return null;

        const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
        const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

        if (!gameJustFinished && !gameJustAbandoned) return null;
        if (afterData.rewardsDistributed === true) return null;

        const betAmount = afterData.betAmount || 0;
        if (betAmount === 0) return null;
        if (afterData.quotasCollected !== true) return null;

        const numberOfPlayers = afterData.numberOfPlayers || 3;
        const hostId   = afterData.hostId;
        const guestId  = afterData.guestId;
        const guest2Id = afterData.guest2Id || null;
        const guest3Id = afterData.guest3Id || null;
        const winnerId = afterData.winnerId;
        const abandonedBy = afterData.abandonedBy;

        const allPlayerIds = [hostId, guestId, guest2Id, guest3Id].filter(id => !!id);
        if (allPlayerIds.length === 0) return null;

        let auditData = { gameId, databaseId, function: 'distributeDominoPaseGameRewards' };

        try {
          await db.runTransaction(async (transaction) => {
            const gameRef = db.collection('domino_pase_games').doc(gameId);

            const security = await readSecurityDocs(db, transaction);
            const gameDoc = await transaction.get(gameRef);

            const playerDocs = {};
            for (const pid of allPlayerIds) {
              playerDocs[pid] = { doc: await transaction.get(db.collection('users').doc(pid)) };
            }

            const currentGameData = gameDoc.data();

            if (currentGameData?.rewardsDistributed === true) return;
            if (currentGameData?.quotasCollected !== true) return;

            if (security.config.bettingEnabled === false) {
              transaction.update(gameRef, {
                rewardsDistributed: true, distributionBlocked: 'betting_disabled',
                rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              auditData.blocked = 'betting_disabled';
              return;
            }

            const suspendedIds = allPlayerIds.filter(pid => playerDocs[pid]?.doc?.data()?.suspended === true);
            if (suspendedIds.length > 0) {
              transaction.update(gameRef, {
                rewardsDistributed: true, distributionBlocked: 'user_suspended',
                suspendedUsers: suspendedIds,
                rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              auditData.blocked = 'user_suspended';
              return;
            }

            const requiredBalance = betAmount;
            const commissionAmt = currentGameData.gameSettings?.commissionAmount
              || Math.ceil(requiredBalance * numberOfPlayers * 0.20);
            const totalPot = currentGameData.totalPot || (requiredBalance * numberOfPlayers);
            const winnerPrize = totalPot - commissionAmt;

            const effectiveWinnerId = gameJustAbandoned
              ? (currentGameData.winnerId || (abandonedBy === hostId ? guestId : hostId))
              : winnerId;

            if (!effectiveWinnerId || !allPlayerIds.includes(effectiveWinnerId)) return;

            const playerNumMap = {};
            if (hostId)   playerNumMap['player1'] = hostId;
            if (guestId)  playerNumMap['player2'] = guestId;
            if (guest2Id) playerNumMap['player3'] = guest2Id;
            if (guest3Id) playerNumMap['player4'] = guest3Id;

            const passPayments  = currentGameData.gameSettings?.passPayments || {};
            const rawPassNetMap = currentGameData.gameSettings?.passNet
                               || currentGameData.passNet
                               || {};
            const addData       = currentGameData.gameSettings?.additionalData || {};

            const passNet = {};
            for (const [key, pid] of Object.entries(playerNumMap)) {
              let value = 0;
              const data = passPayments[key] || passPayments[pid] || {};
              if (data.net !== undefined) {
                value = Number(data.net);
              } else if (data.received !== undefined || data.paid !== undefined) {
                value = Number(data.received || 0) - Number(data.paid || 0);
              } else if (typeof rawPassNetMap === 'object' && rawPassNetMap !== null) {
                if (rawPassNetMap[pid] !== undefined) value = Number(rawPassNetMap[pid]);
                else if (rawPassNetMap[key] !== undefined) value = Number(rawPassNetMap[key]);
              } else if (addData.passNet !== undefined && pid === effectiveWinnerId) {
                value = Number(addData.passNet);
              }
              passNet[pid] = Number.isFinite(value) ? value : 0;
            }

            for (const pid of allPlayerIds) {
              if (passNet[pid] === undefined) passNet[pid] = 0;
            }

            const settlement = {};
            for (const pid of allPlayerIds) {
              const base = (pid === effectiveWinnerId) ? winnerPrize : 0;
              settlement[pid] = base + (passNet[pid] || 0);
            }

            let totalPlayerPayout = 0;
            for (const pid of allPlayerIds) {
              const netAmount = settlement[pid] || 0;
              if (netAmount === 0) continue;

              const userRef = db.collection('users').doc(pid);
              if (netAmount > 0) {
                transaction.update(userRef, { diamondsEarned: admin.firestore.FieldValue.increment(netAmount) });
                totalPlayerPayout += netAmount;
              } else {
                transaction.update(userRef, { diamonds: admin.firestore.FieldValue.increment(netAmount) });
              }
            }

            transaction.update(gameRef, {
              rewardsDistributed: true,
              rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
              distribution: {
                winnerId: effectiveWinnerId, winnerPrize,
                houseCommission: commissionAmt, totalPot, betAmount,
                requiredBalance, currencyType: 'diamonds',
                commissionRate: 0.20,
                reason: gameJustAbandoned ? 'abandoned' : 'win',
                passNet, settlement,
              },
            });

            writePayoutTracking(transaction, security, totalPlayerPayout, gameId);
            auditData = { ...auditData, winnerId: effectiveWinnerId, winnerPrize, houseCommission: commissionAmt };
          });

          await logAudit(db, auditData);
          return null;
        } catch (error) {
          console.error(`[DominoPase ${gameId}] ERROR:`, error);
          throw error;
        }
      }
    );

    return fns;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Export functions for PROD database
  // ═══════════════════════════════════════════════════════════════════════════
  const prodFunctions = createGameFunctions(prodDb, 'prod', '');
  Object.assign(exports, prodFunctions);

  // ═══════════════════════════════════════════════════════════════════════════
  // Export functions for STAGE database
  // ═══════════════════════════════════════════════════════════════════════════
  const stageFunctions = createGameFunctions(stageDb, 'stage', 'Stage');
  Object.assign(exports, stageFunctions);
