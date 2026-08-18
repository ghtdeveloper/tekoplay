  const {setGlobalOptions} = require("firebase-functions/v2/options");
    const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
    const logger = require("firebase-functions/logger");
    const admin = require('firebase-admin');

    admin.initializeApp();
    const db = admin.firestore();

    // Configurar opciones globales
    setGlobalOptions({ 
      maxInstances: 10,
      region: 'us-east1'
    });

    // Función para enviar notificaciones cuando se crea una invitación
    exports.sendGameInvitationNotification = onDocumentCreated(
      {
        document: 'game_invitations/{invitationId}',
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
          const tokenDoc = await admin.firestore()
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
              title: 'Nueva invitación de juego',
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

    // Función para notificar movimientos en el juego
    exports.sendGameMoveNotification = onDocumentUpdated(
      {
        document: 'multiplayer_games/{gameId}',
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

          const tokenDoc = await admin.firestore()
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
              body: `${opponentName} ha movido. ¡Es tu turno!`,
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

    // Función para notificar cuando termina un juego
    exports.sendGameFinishedNotification = onDocumentUpdated(
      {
        document: 'multiplayer_games/{gameId}',
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

            const tokenDoc = await admin.firestore()
              .collection('user_tokens')
              .doc(player.id)
              .get();

            if (!tokenDoc.exists) return null;

            const userToken = tokenDoc.data().token;

            let title, body;
            if (after.result === 'draw') {
              title = 'Juego terminado';
              body = 'La partida terminó en empate';
            } else if (after.winnerId === player.id) {
              title = '¡Felicidades!';
              body = '¡Has ganado la partida!';
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

  
  /**
   * Calcula la distribución de recompensas.
   *
   * Modo apuesta  (diamantes): casa cobra 10% del pot → ganador recibe 90% del pot.
   * Modo diversión (monedas) : casa cobra 30% del pot → ganador recibe 70% del pot.
   *
   * Empate apuesta  : cada jugador recupera 90% de su apuesta (casa: 10%).
   * Empate diversión: cada jugador recupera 15% de su cuota   (casa: 70%).
   *
   * Se usa Math.floor para que cualquier fracción sobrante siempre vaya a la casa.
   *
   * @param {number}  quotaAmount - Apuesta de cada jugador (pot total = quotaAmount × 2).
   * @param {boolean} isBetMode   - true = modo apuesta con diamantes.
   */
  function calcDistribution(quotaAmount, isBetMode) {
    const pot = quotaAmount * 2;
    if (isBetMode) {
      const winnerPrize         = Math.floor(pot * 0.90); // ganador recibe 90% del pot
      const drawReturn          = Math.floor(quotaAmount * 0.90); // empate: recupera 90% de su apuesta
      const houseCommissionWin  = pot - winnerPrize;
      const houseCommissionDraw = pot - (drawReturn * 2);
      return { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw };
    } else {
      const winnerPrize         = Math.floor(pot * 0.70); // ganador recibe 70% del pot
      const drawReturn          = Math.floor(quotaAmount * 0.15); // empate: recupera 15% de su cuota
      const houseCommissionWin  = pot - winnerPrize;
      const houseCommissionDraw = pot - (drawReturn * 2);
      return { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw };
    }
  }

   // FUNCIÓN: Distribuir recompensas del juego (finished Y abandoned)
   // SCOPE: juegos de ajedrez multijugador NO-online-matchmaking (invitados directos).
   // Los juegos de matchmaking online son manejados por distributeOnlineBetGameRewards.
exports.distributeGameRewards = onDocumentUpdated(
  {
    document: 'multiplayer_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    console.log(`\n🎮 [${gameId}] === INICIO distributeGameRewards ===`);
    console.log(`📊 Status: "${beforeData?.status}" → "${afterData?.status}"`);
    console.log(`💎 rewardsDistributed: ${afterData?.rewardsDistributed}`);
    console.log(`✅ quotasCollected: ${afterData?.quotasCollected}`);
    console.log(`💰 totalPot: ${afterData?.totalPot}`);
    console.log(`🎯 result: "${afterData?.result}"`);
    console.log(`🏆 winnerId: ${afterData?.winnerId}`);
    console.log(`💱 currencyType: ${afterData?.currencyType}`);

    if (!beforeData || !afterData) {
      console.log(`❌ [${gameId}] No hay datos before/after`);
      return null;
    }

    // ── GUARDIA: los juegos de matchmaking online los maneja distributeOnlineBetGameRewards ──
    if (afterData.gameSettings?.isOnlineMatchmaking === true) {
      console.log(`⏭️ [${gameId}] Online matchmaking → manejado por distributeOnlineBetGameRewards (SALIENDO)\n`);
      return null;
    }

    const gameJustFinished =
      beforeData.status !== 'finished' &&
      afterData.status === 'finished';

    const gameJustAbandoned =
      beforeData.status !== 'abandoned' &&
      afterData.status === 'abandoned';

    if (!gameJustFinished && !gameJustAbandoned) {
      console.log(`⏭️ [${gameId}] No es cambio a finished/abandoned (SALIENDO)\n`);
      return null;
    }

    if (afterData.rewardsDistributed === true) {
      console.log(`⚠️ [${gameId}] Recompensas ya distribuidas (SALIENDO)\n`);
      return null;
    }

    if (afterData.quotasCollected !== true) {
      console.log(`⚠️ [${gameId}] ❌ Cuotas no cobradas (SALIENDO)`);
      return null;
    }

    const winnerId = afterData.winnerId;
    const hostId = afterData.hostId;
    const guestId = afterData.guestId;
    const totalPot = afterData.totalPot || 0;
    const currencyType = afterData.currencyType || 'coins';
    const result = afterData.result;
    const abandonedBy = afterData.abandonedBy;
    // Modo apuesta: diamantes con betAmount > 0
    const isBetMode = currencyType === 'diamonds' && (afterData.betAmount || 0) > 0;

    if (!guestId || totalPot === 0) {
      console.log(`❌ [${gameId}] Datos insuficientes (guestId: ${guestId}, totalPot: ${totalPot})\n`);
      return null;
    }

    console.log(`\n🚀 [${gameId}] PROCEDIENDO A DISTRIBUIR`);
    console.log(`   isBetMode: ${isBetMode} | currency: ${currencyType}`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef = db.collection('multiplayer_games').doc(gameId);
        const hostRef = db.collection('users').doc(hostId);
        const guestRef = db.collection('users').doc(guestId);

        const hostDoc  = await transaction.get(hostRef);
        const guestDoc = await transaction.get(guestRef);
        const gameDoc  = await transaction.get(gameRef);

        if (!hostDoc.exists || !guestDoc.exists) throw new Error('Usuarios no encontrados');

        // Re-verificar dentro de la transacción (protección idempotente)
        const currentGameData = gameDoc.data();
        if (currentGameData && currentGameData.rewardsDistributed === true) {
          console.log(`⚠️ [${gameId}] Ya distribuido dentro de transacción\n`);
          return;
        }

        const hostData  = hostDoc.data();
        const guestData = guestDoc.data();

        const quotaAmount = totalPot / 2;
        const { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw } =
          calcDistribution(quotaAmount, isBetMode);

        console.log(`\n💵 CÁLCULOS [${isBetMode ? 'APUESTA 10%' : 'DIVERSIÓN 30%'}]:`);
        console.log(`   quotaAmount: ${quotaAmount} | winnerPrize: ${winnerPrize} | houseWin: ${houseCommissionWin} | drawReturn: ${drawReturn}`);

        let hostReward  = 0;
        let guestReward = 0;
        let actualHouseCommission = 0;

        if (gameJustAbandoned) {
          if (abandonedBy === hostId) {
            guestReward = winnerPrize;
            console.log(`🚪 Host abandonó → Guest gana ${winnerPrize}`);
          } else if (abandonedBy === guestId) {
            hostReward = winnerPrize;
            console.log(`🚪 Guest abandonó → Host gana ${winnerPrize}`);
          }
          actualHouseCommission = totalPot - hostReward - guestReward;
        } else {
          if (result === 'draw') {
            hostReward  = drawReturn;
            guestReward = drawReturn;
            actualHouseCommission = houseCommissionDraw;
            console.log(`🤝 EMPATE → Cada uno recibe ${drawReturn} | Casa: ${houseCommissionDraw}`);
          } else if (winnerId === hostId) {
            hostReward  = winnerPrize;
            actualHouseCommission = houseCommissionWin;
            console.log(`✅ HOST GANÓ → ${winnerPrize} | Casa: ${houseCommissionWin}`);
          } else if (winnerId === guestId) {
            guestReward = winnerPrize;
            actualHouseCommission = houseCommissionWin;
            console.log(`✅ GUEST GANÓ → ${winnerPrize} | Casa: ${houseCommissionWin}`);
          }
        }

        // Verificación matemática — NUNCA debe fallar
        const totalDistributed = hostReward + guestReward + actualHouseCommission;
        if (totalDistributed !== totalPot) {
          throw new Error(`MATH ERROR: totalPot(${totalPot}) ≠ distributed(${totalDistributed})`);
        }

        console.log(`\n💵 DISTRIBUCIÓN FINAL: Host+${hostReward} | Guest+${guestReward} | Casa+${actualHouseCommission}`);

        if (currencyType === 'coins') {
          const hostOldCoins  = hostData.coins  || 0;
          const guestOldCoins = guestData.coins || 0;
          console.log(`💰 Monedas: Host ${hostOldCoins}+${hostReward}=${hostOldCoins+hostReward} | Guest ${guestOldCoins}+${guestReward}=${guestOldCoins+guestReward}`);
          transaction.update(hostRef,  { coins: hostOldCoins  + hostReward });
          transaction.update(guestRef, { coins: guestOldCoins + guestReward });
        } else {
          const hostOldDiamonds  = hostData.diamonds  || 0;
          const guestOldDiamonds = guestData.diamonds || 0;
          const hostNetGain  = hostReward  - quotaAmount;
          const guestNetGain = guestReward - quotaAmount;
          console.log(`💎 Diamantes: Host ${hostOldDiamonds}+${hostReward}=${hostOldDiamonds+hostReward} (net:${hostNetGain}) | Guest ${guestOldDiamonds}+${guestReward}=${guestOldDiamonds+guestReward} (net:${guestNetGain})`);
          transaction.update(hostRef,  { diamonds: hostOldDiamonds  + hostReward,  diamondsEarned: (hostData.diamondsEarned  || 0) + Math.max(0, hostNetGain)  });
          transaction.update(guestRef, { diamonds: guestOldDiamonds + guestReward, diamondsEarned: (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain) });
        }

        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            hostReward,
            guestReward,
            houseCommission: actualHouseCommission,
            currencyType,
            isBetMode,
            commissionRate: isBetMode ? 0.10 : 0.30,
            reason: gameJustAbandoned ? 'abandoned' : result,
            abandonedBy: abandonedBy || null,
          },
        });

        console.log(`✅ [${gameId}] Transacción completada\n`);
      });

      return null;
    } catch (error) {
      console.error(`❌ [${gameId}] ERROR en distributeGameRewards:`, error);
      throw error;
    }
  }
);


// FUNCIÓN: Distribuir recompensas del juego ONLINE DE APUESTA (solo diamantes, matchmaking)
// Requiere quotasCollected === true (cobradas por el cliente al unirse el guest).
// Usa calcDistribution() como única fuente de verdad — misma fórmula que los demás modos.
exports.distributeOnlineBetGameRewards = onDocumentUpdated(
  {
    document: 'multiplayer_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    console.log(`\n💎 [${gameId}] === INICIO distributeOnlineBetGameRewards ===`);
    console.log(`📊 Status: "${beforeData?.status}" → "${afterData?.status}"`);
    console.log(`✅ quotasCollected: ${afterData?.quotasCollected}`);
    console.log(`💎 rewardsDistributed: ${afterData?.rewardsDistributed}`);
    console.log(`💰 betAmount: ${afterData?.betAmount} | totalPot: ${afterData?.totalPot}`);
    console.log(`🎯 result: "${afterData?.result}" | winnerId: ${afterData?.winnerId}`);

    if (!beforeData || !afterData) return null;

    // Solo juegos de matchmaking online con diamantes
    if (afterData.currencyType !== 'diamonds' || !afterData.gameSettings?.isOnlineMatchmaking) {
      console.log(`⏭️ [${gameId}] No aplica (SALIENDO)\n`);
      return null;
    }

    const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
    const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

    if (!gameJustFinished && !gameJustAbandoned) {
      console.log(`⏭️ [${gameId}] Sin cambio a finished/abandoned (SALIENDO)\n`);
      return null;
    }

    if (afterData.rewardsDistributed === true) {
      console.log(`⚠️ [${gameId}] Recompensas ya distribuidas (SALIENDO)\n`);
      return null;
    }

    // Las cuotas DEBEN haber sido cobradas por el cliente (igual que distributeGameRewards)
    if (afterData.quotasCollected !== true) {
      console.log(`⚠️ [${gameId}] quotasCollected !== true — sin cuotas cobradas (SALIENDO)\n`);
      return null;
    }

    const hostId      = afterData.hostId;
    const guestId     = afterData.guestId;
    const totalPot    = afterData.totalPot || 0;
    const betAmount   = afterData.betAmount || 0;
    const winnerId    = afterData.winnerId;
    const result      = afterData.result;
    const abandonedBy = afterData.abandonedBy;

    if (!hostId || !guestId || totalPot === 0) {
      console.log(`❌ [${gameId}] Datos insuficientes (hostId:${hostId}, guestId:${guestId}, totalPot:${totalPot})\n`);
      return null;
    }

    console.log(`\n🚀 [${gameId}] Procediendo | tipo: ${gameJustAbandoned ? 'ABANDONO' : 'VICTORIA'} | pot: ${totalPot} diamantes`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef  = db.collection('multiplayer_games').doc(gameId);
        const hostRef  = db.collection('users').doc(hostId);
        const guestRef = db.collection('users').doc(guestId);

        const [gameDoc] = await Promise.all([transaction.get(gameRef)]);

        // Re-verificar idempotencia dentro de la transacción
        const currentGameData = gameDoc.data();
        if (currentGameData?.rewardsDistributed === true) {
          console.log(`⚠️ [${gameId}] Ya distribuido (transacción)\n`);
          return;
        }

        // Usar calcDistribution — misma fórmula que distributeGameRewards y distributeLudoGameRewards
        const quotaAmount = totalPot / 2; // = betAmount por jugador
        const { winnerPrize, drawReturn, houseCommissionWin, houseCommissionDraw } =
          calcDistribution(quotaAmount, true /* isBetMode = diamonds */);

        console.log(`\n💵 CÁLCULOS [APUESTA 10% comisión]:`);
        console.log(`   pot: ${totalPot} | quotaAmount: ${quotaAmount}`);
        console.log(`   winnerPrize: ${winnerPrize} | drawReturn: ${drawReturn}`);
        console.log(`   houseWin: ${houseCommissionWin} | houseDraw: ${houseCommissionDraw}`);

        let hostReward = 0;
        let guestReward = 0;
        let actualHouseCommission = 0;
        let distributionReason = '';

        if (gameJustAbandoned) {
          distributionReason = 'abandoned';
          if (abandonedBy === hostId) {
            guestReward = winnerPrize;
            console.log(`🚪 Host abandonó → Guest gana ${guestReward}`);
          } else if (abandonedBy === guestId) {
            hostReward = winnerPrize;
            console.log(`🚪 Guest abandonó → Host gana ${hostReward}`);
          }
          actualHouseCommission = totalPot - hostReward - guestReward;
        } else if (result === 'draw') {
          distributionReason = 'draw';
          hostReward  = drawReturn;
          guestReward = drawReturn;
          actualHouseCommission = houseCommissionDraw;
          console.log(`🤝 EMPATE → Cada uno recibe ${drawReturn} | Casa: ${houseCommissionDraw}`);
        } else if (winnerId === hostId) {
          distributionReason = 'host_won';
          hostReward = winnerPrize;
          actualHouseCommission = houseCommissionWin;
          console.log(`✅ HOST GANÓ → ${winnerPrize} | Casa: ${houseCommissionWin}`);
        } else if (winnerId === guestId) {
          distributionReason = 'guest_won';
          guestReward = winnerPrize;
          actualHouseCommission = houseCommissionWin;
          console.log(`✅ GUEST GANÓ → ${winnerPrize} | Casa: ${houseCommissionWin}`);
        }

        // Verificación matemática — nunca debe fallar
        const totalDistributed = hostReward + guestReward + actualHouseCommission;
        if (totalDistributed !== totalPot) {
          throw new Error(`MATH ERROR: totalPot(${totalPot}) ≠ distributed(${totalDistributed})`);
        }

        const hostNetGain  = hostReward  - quotaAmount;
        const guestNetGain = guestReward - quotaAmount;

        console.log(`\n💎 DISTRIBUCIÓN FINAL: Host+${hostReward} | Guest+${guestReward} | Casa+${actualHouseCommission}`);
        console.log(`📈 NETO: Host ${hostNetGain >= 0 ? '+' : ''}${hostNetGain} | Guest ${guestNetGain >= 0 ? '+' : ''}${guestNetGain}`);

        // FieldValue.increment — atómico, no requiere leer el balance actual
        if (hostReward > 0) {
          transaction.update(hostRef, {
            diamonds:       admin.firestore.FieldValue.increment(hostReward),
            diamondsEarned: admin.firestore.FieldValue.increment(Math.max(0, hostNetGain)),
          });
        }
        if (guestReward > 0) {
          transaction.update(guestRef, {
            diamonds:       admin.firestore.FieldValue.increment(guestReward),
            diamondsEarned: admin.firestore.FieldValue.increment(Math.max(0, guestNetGain)),
          });
        }

        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            hostReward, guestReward,
            houseCommission: actualHouseCommission,
            totalPot, betAmount: quotaAmount,
            currencyType: 'diamonds',
            isBetMode: true,
            commissionRate: 0.10,
            reason: distributionReason,
            abandonedBy: abandonedBy || null,
            hostNetGain, guestNetGain,
          },
        });

        console.log(`✅ [${gameId}] Transacción completada\n`);
      });

      return null;
    } catch (error) {
      console.error(`❌ [${gameId}] ERROR en distributeOnlineBetGameRewards:`, error);
      throw error;
    }
  }
);

// ─── Ludo: distribuir recompensas al finalizar / abandonar ───────────────────
exports.distributeLudoGameRewards = onDocumentUpdated(
  {
    document: 'ludo_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData  = event.data?.after.data();

    console.log(`\n🎲 [Ludo ${gameId}] === INICIO FUNCIÓN ===`);
    console.log(`📊 Status: "${beforeData?.status}" → "${afterData?.status}"`);
    console.log(`💎 rewardsDistributed: ${afterData?.rewardsDistributed}`);
    console.log(`💰 betAmount: ${afterData?.betAmount}`);
    console.log(`🏆 winnerId: ${afterData?.winnerId}`);
    console.log(`💱 currencyType: ${afterData?.currencyType}`);

    if (!beforeData || !afterData) return null;

    const gameJustFinished =
      beforeData.status !== 'finished' && afterData.status === 'finished';
    const gameJustAbandoned =
      beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

    if (!gameJustFinished && !gameJustAbandoned) {
      console.log(`⏭️ [Ludo ${gameId}] Sin cambio a finished/abandoned (SALIENDO)\n`);
      return null;
    }

    if (afterData.rewardsDistributed === true) {
      console.log(`⚠️ [Ludo ${gameId}] Recompensas ya distribuidas (SALIENDO)\n`);
      return null;
    }

    const betAmount    = afterData.betAmount || 0;
    const currencyType = afterData.currencyType || 'coins';
    if (betAmount === 0) {
      console.log(`⏭️ [Ludo ${gameId}] Sin apuesta (SALIENDO)\n`);
      return null;
    }

    const hostId      = afterData.hostId;
    const winnerId    = afterData.winnerId;
    const abandonedBy = afterData.abandonedBy;

    // Recopilar todos los IDs reales (excluir bots que empiezan con 'bot_')
    const allSlotIds = [
      hostId,
      afterData.guest2Id,
      afterData.guest3Id,
      afterData.guest4Id,
    ];
    const realPlayerIds = allSlotIds.filter(id => id && !String(id).startsWith('bot_'));

    if (realPlayerIds.length < 2) {
      console.log(`❌ [Ludo ${gameId}] Menos de 2 jugadores reales (SALIENDO)\n`);
      return null;
    }

    console.log(`\n🚀 [Ludo ${gameId}] ¡PROCEDIENDO A DISTRIBUIR! (${realPlayerIds.length} jugadores reales)`);
    console.log(`   Tipo: ${gameJustAbandoned ? 'ABANDONO' : 'VICTORIA'}`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef = db.collection('ludo_games').doc(gameId);

        const gameDoc = await transaction.get(gameRef);
        const currentGameData = gameDoc.data();
        if (currentGameData && currentGameData.rewardsDistributed === true) {
          console.log(`⚠️ [Ludo ${gameId}] Ya distribuido en transacción\n`);
          return;
        }

        // Las cuotas deben haberse cobrado en el cliente al unirse los guests reales.
        if (currentGameData?.quotasCollected !== true) {
          console.log(`⚠️ [Ludo ${gameId}] Cuotas no cobradas (SALIENDO)\n`);
          return;
        }

        const isCoins = currencyType === 'coins';
        const isBetMode = !isCoins && betAmount > 0;
        const realPlayerCount = realPlayerIds.length;

        if (gameJustAbandoned) {
          // Refund all non-abandoning players; the abandoner's bet goes to the house
          const nonAbandoningIds = realPlayerIds.filter(id => id !== abandonedBy);

          if (nonAbandoningIds.length === 0) {
            console.log(`⚠️ [Ludo ${gameId}] Sin jugadores a quienes reembolsar (SALIENDO)\n`);
            return;
          }

          console.log(`🔄 [Ludo] Abandono — reembolsando ${nonAbandoningIds.length} jugadores, casa retiene apuesta de: ${abandonedBy}`);

          for (const playerId of nonAbandoningIds) {
            const playerRef = db.collection('users').doc(playerId);
            if (isCoins) {
              transaction.update(playerRef, { coins: admin.firestore.FieldValue.increment(betAmount) });
            } else {
              transaction.update(playerRef, { diamonds: admin.firestore.FieldValue.increment(betAmount) });
            }
            console.log(`   ↩️ Reembolso a ${playerId}: +${betAmount} ${currencyType}`);
          }

          transaction.update(gameRef, {
            rewardsDistributed: true,
            rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
            distribution: {
              type: 'abandoned_refund',
              abandonedBy,
              refundedPlayers: nonAbandoningIds,
              refundAmount: betAmount,
              houseKeeps: betAmount,
              currencyType,
              isBetMode,
            },
          });

          console.log(`✅ [Ludo ${gameId}] Reembolsos completados (casa retiene: ${betAmount} ${currencyType})\n`);
          return;
        }

        // Victoria normal — ganador recibe el pot menos comisión
        const totalPot = betAmount * realPlayerCount;
        const commissionRate = isBetMode ? 0.10 : 0.30;
        const winnerPrize = Math.floor(totalPot * (1 - commissionRate));
        const houseCommission = totalPot - winnerPrize;

        console.log(`💵 [Ludo] players:${realPlayerCount} | bet:${betAmount} | totalPot:${totalPot} | winner:${winnerPrize} | casa:${houseCommission} | comisión:${isBetMode ? '10%' : '30%'}`);

        if (!realPlayerIds.includes(winnerId)) {
          console.log(`⚠️ [Ludo ${gameId}] Ganador no es jugador real (SALIENDO)\n`);
          return;
        }

        const winnerRef = db.collection('users').doc(winnerId);
        const winnerNetGain = winnerPrize - betAmount;
        console.log(`   ✅ Ganador: ${winnerId} → +${winnerPrize} (neto ${winnerNetGain >= 0 ? '+' : ''}${winnerNetGain})`);

        if (winnerPrize + houseCommission !== totalPot) {
          throw new Error(`[Ludo] MATH ERROR: totalPot(${totalPot}) ≠ distributed(${winnerPrize + houseCommission})`);
        }

        if (isCoins) {
          transaction.update(winnerRef, { coins: admin.firestore.FieldValue.increment(winnerPrize) });
        } else {
          transaction.update(winnerRef, {
            diamonds: admin.firestore.FieldValue.increment(winnerPrize),
            diamondsEarned: admin.firestore.FieldValue.increment(Math.max(0, winnerNetGain)),
          });
        }

        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            winnerId,
            winnerPrize,
            houseCommission,
            totalPot,
            betAmount,
            realPlayerCount,
            currencyType,
            isBetMode,
            commissionRate,
            reason: 'win',
            winnerNetGain,
          },
        });

        console.log(`✅ [Ludo ${gameId}] Distribución completada\n`);
      });

      return null;
    } catch (error) {
      console.error(`\n❌ [Ludo ${gameId}] ERROR:`, error);
      throw error;
    }
  }
);

exports.distributeDominoGameRewards = onDocumentUpdated(
  {
    document: 'domino_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData  = event.data?.after.data();

    console.log(`\n🁣 [Domino ${gameId}] === INICIO FUNCIÓN ===`);
    console.log(`📊 Status: "${beforeData?.status}" → "${afterData?.status}"`);
    console.log(`💎 rewardsDistributed: ${afterData?.rewardsDistributed}`);
    console.log(`💰 betAmount: ${afterData?.betAmount}`);
    console.log(`🏆 winnerId: ${afterData?.winnerId}`);
    console.log(`💱 currencyType: ${afterData?.currencyType}`);

    if (!beforeData || !afterData) return null;

    const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
    const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

    if (!gameJustFinished && !gameJustAbandoned) {
      console.log(`⏭️ [Domino ${gameId}] Sin cambio a finished/abandoned (SALIENDO)\n`);
      return null;
    }

    if (afterData.rewardsDistributed === true) {
      console.log(`⚠️ [Domino ${gameId}] Recompensas ya distribuidas (SALIENDO)\n`);
      return null;
    }

    const betAmount    = afterData.betAmount || 0;
    const currencyType = afterData.currencyType || 'coins';
    if (betAmount === 0) {
      console.log(`⏭️ [Domino ${gameId}] Sin apuesta (SALIENDO)\n`);
      return null;
    }

    const hostId      = afterData.hostId;
    const guestId     = afterData.guestId;
    const guest2Id    = afterData.guest2Id || null;
    const guest3Id    = afterData.guest3Id || null;
    const winnerId    = afterData.winnerId;
    const abandonedBy = afterData.abandonedBy;
    const numberOfPlayers = afterData.numberOfPlayers || 2;

    const allPlayerIds = [hostId, guestId, guest2Id, guest3Id].filter(id => !!id);
    const realPlayerIds = allPlayerIds.filter(id => !String(id).startsWith('bot_'));

    if (realPlayerIds.length === 0) {
      console.log(`❌ [Domino ${gameId}] Sin jugadores reales (SALIENDO)\n`);
      return null;
    }

    if (afterData.quotasCollected !== true) {
      console.log(`⚠️ [Domino ${gameId}] quotasCollected !== true — cuotas no cobradas (SALIENDO)\n`);
      return null;
    }

    console.log(`\n🚀 [Domino ${gameId}] ¡PROCEDIENDO A DISTRIBUIR!`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef = db.collection('domino_games').doc(gameId);
        const gameDoc = await transaction.get(gameRef);
        const currentGameData = gameDoc.data();

        if (currentGameData?.rewardsDistributed === true) {
          console.log(`⚠️ [Domino ${gameId}] Ya distribuido en transacción\n`);
          return;
        }

        if (currentGameData?.quotasCollected !== true) {
          console.log(`⚠️ [Domino ${gameId}] Cuotas no cobradas (transacción, SALIENDO)\n`);
          return;
        }

        const isCoins   = currencyType === 'coins';
        const isBetMode = !isCoins && betAmount > 0;
        const realPlayerCount = realPlayerIds.length;
        // Use stored totalPot (reflects only real players who paid), fallback to calculation
        const totalPot  = currentGameData.totalPot || (betAmount * realPlayerCount);
        const commissionRate = isBetMode ? 0.10 : 0.30;
        const winnerPrize    = Math.floor(totalPot * (1 - commissionRate));
        const houseCommission = totalPot - winnerPrize;

        console.log(`💵 [Domino] bet:${betAmount} | realPlayers:${realPlayerCount} | totalPot:${totalPot} | winner:${winnerPrize} | casa:${houseCommission}`);

        const effectiveWinnerId = gameJustAbandoned
          ? (currentGameData.winnerId || (abandonedBy === hostId ? guestId : hostId))
          : winnerId;

        if (!realPlayerIds.includes(effectiveWinnerId)) {
          console.log(`⚠️ [Domino ${gameId}] Ganador no es jugador real (SALIENDO)\n`);
          return;
        }

        const winnerRef    = db.collection('users').doc(effectiveWinnerId);
        const winnerNetGain = winnerPrize - betAmount;

        if (isCoins) {
          transaction.update(winnerRef, { coins: admin.firestore.FieldValue.increment(winnerPrize) });
        } else {
          transaction.update(winnerRef, {
            diamonds: admin.firestore.FieldValue.increment(winnerPrize),
            diamondsEarned: admin.firestore.FieldValue.increment(Math.max(0, winnerNetGain)),
          });
        }

        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            winnerId: effectiveWinnerId,
            winnerPrize,
            houseCommission,
            totalPot,
            betAmount,
            currencyType,
            isBetMode,
            commissionRate,
            reason: gameJustAbandoned ? 'abandoned' : 'win',
            winnerNetGain,
          },
        });

        console.log(`✅ [Domino ${gameId}] Distribución completada\n`);
      });

      return null;
    } catch (error) {
      console.error(`\n❌ [Domino ${gameId}] ERROR:`, error);
      throw error;
    }
  }
);

// =============================================================================
// DOMINO PASE — Distribute rewards with pass payment settlement
// =============================================================================
exports.distributeDominoPaseGameRewards = onDocumentUpdated(
  {
    document: 'domino_pase_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData  = event.data?.after.data();

    console.log(`\n🁣 [DominoPase ${gameId}] === INICIO FUNCIÓN ===`);
    console.log(`📊 Status: "${beforeData?.status}" → "${afterData?.status}"`);
    console.log(`💎 rewardsDistributed: ${afterData?.rewardsDistributed}`);
    console.log(`💰 betAmount: ${afterData?.betAmount}`);
    console.log(`🏆 winnerId: ${afterData?.winnerId}`);

    if (!beforeData || !afterData) return null;

    const gameJustFinished  = beforeData.status !== 'finished'  && afterData.status === 'finished';
    const gameJustAbandoned = beforeData.status !== 'abandoned' && afterData.status === 'abandoned';

    if (!gameJustFinished && !gameJustAbandoned) {
      console.log(`⏭️ [DominoPase ${gameId}] Sin cambio a finished/abandoned (SALIENDO)\n`);
      return null;
    }

    if (afterData.rewardsDistributed === true) {
      console.log(`⚠️ [DominoPase ${gameId}] Recompensas ya distribuidas (SALIENDO)\n`);
      return null;
    }

    const betAmount = afterData.betAmount || 0;
    if (betAmount === 0) {
      console.log(`⏭️ [DominoPase ${gameId}] Sin apuesta (SALIENDO)\n`);
      return null;
    }

    if (afterData.quotasCollected !== true) {
      console.log(`⚠️ [DominoPase ${gameId}] quotasCollected !== true (SALIENDO)\n`);
      return null;
    }

    const numberOfPlayers = afterData.numberOfPlayers || 3;
    const hostId   = afterData.hostId;
    const guestId  = afterData.guestId;
    const guest2Id = afterData.guest2Id || null;
    const guest3Id = afterData.guest3Id || null;
    const winnerId = afterData.winnerId;
    const abandonedBy = afterData.abandonedBy;

    const allPlayerIds = [hostId, guestId, guest2Id, guest3Id].filter(id => !!id);

    if (allPlayerIds.length === 0) {
      console.log(`❌ [DominoPase ${gameId}] Sin jugadores (SALIENDO)\n`);
      return null;
    }

    console.log(`\n🚀 [DominoPase ${gameId}] ¡PROCEDIENDO A DISTRIBUIR!`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef = db.collection('domino_pase_games').doc(gameId);
        const gameDoc = await transaction.get(gameRef);
        const currentGameData = gameDoc.data();

        if (currentGameData?.rewardsDistributed === true) {
          console.log(`⚠️ [DominoPase ${gameId}] Ya distribuido en transacción\n`);
          return;
        }

        if (currentGameData?.quotasCollected !== true) {
          console.log(`⚠️ [DominoPase ${gameId}] Cuotas no cobradas (transacción, SALIENDO)\n`);
          return;
        }

        // Pase formulas: requiredBalance = betAmount * 2, commission = ceil(requiredBalance * nPlayers * 0.10)
        const requiredBalance = betAmount * 2;
        const commissionAmt = currentGameData.gameSettings?.commissionAmount
          || Math.ceil(requiredBalance * numberOfPlayers * 0.10);
        const totalPot = currentGameData.totalPot || (requiredBalance * numberOfPlayers);
        const winnerPrize = totalPot - commissionAmt;

        const effectiveWinnerId = gameJustAbandoned
          ? (currentGameData.winnerId || (abandonedBy === hostId ? guestId : hostId))
          : winnerId;

        if (!effectiveWinnerId || !allPlayerIds.includes(effectiveWinnerId)) {
          console.log(`⚠️ [DominoPase ${gameId}] Ganador no es jugador válido (SALIENDO)\n`);
          return;
        }

        // Build player number mapping
        const playerNumMap = {};
        if (hostId)   playerNumMap['player1'] = hostId;
        if (guestId)  playerNumMap['player2'] = guestId;
        if (guest2Id) playerNumMap['player3'] = guest2Id;
        if (guest3Id) playerNumMap['player4'] = guest3Id;

        // Calculate pass payment net for each player
        const passPayments = currentGameData.gameSettings?.passPayments || {};
        const passNet = {};
        for (const [key, pid] of Object.entries(playerNumMap)) {
          const data = passPayments[key] || {};
          const received = data.received || 0;
          const paid = data.paid || 0;
          passNet[pid] = received - paid;
        }

        // Calculate raw settlement: winner gets winnerPrize + passNet, losers get passNet only
        const rawSettlement = {};
        for (const pid of allPlayerIds) {
          const base = pid === effectiveWinnerId ? winnerPrize : 0;
          rawSettlement[pid] = base + (passNet[pid] || 0);
        }

        // Clamp negatives to 0 and accumulate deficit
        let deficit = 0;
        for (const pid of allPlayerIds) {
          if (rawSettlement[pid] < 0) {
            deficit += -rawSettlement[pid];
            rawSettlement[pid] = 0;
          }
        }

        // Subtract deficit from winner to prevent over-distribution
        if (deficit > 0 && rawSettlement[effectiveWinnerId] !== undefined) {
          rawSettlement[effectiveWinnerId] = Math.max(0, rawSettlement[effectiveWinnerId] - deficit);
        }

        console.log(`💵 [DominoPase] bet:${betAmount} | required:${requiredBalance} | players:${numberOfPlayers} | totalPot:${totalPot} | winnerPrize:${winnerPrize} | commission:${commissionAmt}`);
        console.log(`📊 [DominoPase] passNet:`, JSON.stringify(passNet));
        console.log(`📊 [DominoPase] settlement:`, JSON.stringify(rawSettlement));

        // Distribute to each player (diamonds only in Pase mode)
        // diamonds gets back at most the requiredBalance (refund), net gain goes only to diamondsEarned
        for (const pid of allPlayerIds) {
          const reward = rawSettlement[pid] || 0;
          if (reward > 0) {
            const userRef = db.collection('users').doc(pid);
            const refund = Math.min(reward, requiredBalance);
            const netGain = reward - requiredBalance;
            const updateData = {
              diamonds: admin.firestore.FieldValue.increment(refund),
            };
            if (netGain > 0) {
              updateData.diamondsEarned = admin.firestore.FieldValue.increment(netGain);
            }
            transaction.update(userRef, updateData);
          }
        }

        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            winnerId: effectiveWinnerId,
            winnerPrize,
            houseCommission: commissionAmt,
            totalPot,
            betAmount,
            requiredBalance,
            currencyType: 'diamonds',
            commissionRate: 0.10,
            reason: gameJustAbandoned ? 'abandoned' : 'win',
            passNet,
            settlement: rawSettlement,
          },
        });

        console.log(`✅ [DominoPase ${gameId}] Distribución completada\n`);
      });

      return null;
    } catch (error) {
      console.error(`\n❌ [DominoPase ${gameId}] ERROR:`, error);
      throw error;
    }
  }
);
