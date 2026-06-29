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


// FUNCIÓN: Distribuir recompensas del juego ONLINE DE APUESTA (solo diamantes)
exports.distributeOnlineBetGameRewards = onDocumentUpdated(
  {
    document: 'multiplayer_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    console.log(`\n💎 [${gameId}] === INICIO FUNCIÓN APUESTA ONLINE ===`);
    console.log(`📊 Status: "${beforeData?.status}" → "${afterData?.status}"`);
    console.log(`💎 rewardsDistributed: ${afterData?.rewardsDistributed}`);
    console.log(`✅ quotasCollected: ${afterData?.quotasCollected}`);
    console.log(`💰 betAmount: ${afterData?.betAmount}`);
    console.log(`🎯 result: "${afterData?.result}"`);
    console.log(`🏆 winnerId: ${afterData?.winnerId}`);
    console.log(`💱 currencyType: ${afterData?.currencyType}`);

    if (!beforeData || !afterData) {
      console.log(`❌ [${gameId}] No hay datos before/after`);
      return null;
    }

    // Solo procesar juegos de APUESTA (diamantes) online
    if (afterData.currencyType !== 'diamonds') {
      console.log(`⏭️ [${gameId}] No es juego de apuesta con diamantes (SALIENDO)`);
      return null;
    }

    // Verificar que el juego sea online matchmaking
    if (!afterData.gameSettings?.isOnlineMatchmaking) {
      console.log(`⏭️ [${gameId}] No es juego de matchmaking online (SALIENDO)`);
      return null;
    }

    const gameJustFinished = 
      beforeData.status !== 'finished' && 
      afterData.status === 'finished';
    
    const gameJustAbandoned = 
      beforeData.status !== 'abandoned' && 
      afterData.status === 'abandoned';

    console.log(`🔍 gameJustFinished: ${gameJustFinished}`);
    console.log(`🔍 gameJustAbandoned: ${gameJustAbandoned}`);

    if (!gameJustFinished && !gameJustAbandoned) {
      console.log(`⏭️ [${gameId}] No es cambio a finished/abandoned (SALIENDO)\n`);
      return null;
    }

    if (afterData.rewardsDistributed === true) {
      console.log(`⚠️ [${gameId}] Recompensas ya distribuidas (SALIENDO)\n`);
      return null;
    }

    const hostId = afterData.hostId;
    const guestId = afterData.guestId;
    const betAmount = afterData.betAmount || 0;
    const winnerId = afterData.winnerId;
    const result = afterData.result;
    const abandonedBy = afterData.abandonedBy;

    if (!hostId || !guestId || betAmount === 0) {
      console.log(`❌ [${gameId}] Datos insuficientes para distribuir`);
      console.log(`   hostId: ${hostId}, guestId: ${guestId}, betAmount: ${betAmount}\n`);
      return null;
    }

    console.log(`\n🚀 [${gameId}] ¡PROCEDIENDO CON APUESTA ONLINE!`);
    console.log(`   Tipo de finalización: ${gameJustAbandoned ? 'ABANDONO' : 'FINISHED'}`);
    console.log(`   Cantidad apostada por jugador: ${betAmount} diamantes\n`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef = db.collection('multiplayer_games').doc(gameId);
        const hostRef = db.collection('users').doc(hostId);
        const guestRef = db.collection('users').doc(guestId);

        console.log(`📥 Obteniendo documentos de usuarios...`);
        const hostDoc = await transaction.get(hostRef);
        const guestDoc = await transaction.get(guestRef);
        const gameDoc = await transaction.get(gameRef);

        if (!hostDoc.exists || !guestDoc.exists) {
          throw new Error('Usuarios no encontrados');
        }
        console.log(`✅ Documentos obtenidos correctamente`);

        const currentGameData = gameDoc.data();
        if (currentGameData && currentGameData.rewardsDistributed === true) {
          console.log(`⚠️ [${gameId}] Ya distribuido en transacción\n`);
          return;
        }

        const hostData = hostDoc.data();
        const guestData = guestDoc.data();

        // PASO 1: COBRAR CUOTAS SI NO SE HAN COBRADO
        let quotasAlreadyCollected = currentGameData?.quotasCollected === true;
        let hostCurrentDiamonds = hostData.diamonds || 0;
        let guestCurrentDiamonds = guestData.diamonds || 0;

        if (!quotasAlreadyCollected) {
          console.log(`\n💰 ========== COBRANDO CUOTAS ==========`);
          console.log(`📊 ANTES DE COBRAR:`);
          console.log(`   Host ID: ${hostId}`);
          console.log(`   Host diamonds: ${hostCurrentDiamonds}`);
          console.log(`   Guest ID: ${guestId}`);
          console.log(`   Guest diamonds: ${guestCurrentDiamonds}`);
          console.log(`💵 CUOTA A COBRAR: ${betAmount} diamantes c/u`);

          // Verificar que ambos tengan suficientes diamantes
          if (hostCurrentDiamonds < betAmount) {
            throw new Error(`Host no tiene suficientes diamantes: ${hostCurrentDiamonds} < ${betAmount}`);
          }
          if (guestCurrentDiamonds < betAmount) {
            throw new Error(`Guest no tiene suficientes diamantes: ${guestCurrentDiamonds} < ${betAmount}`);
          }

          // Cobrar las cuotas
          hostCurrentDiamonds -= betAmount;
          guestCurrentDiamonds -= betAmount;

          console.log(`📊 DESPUÉS DE COBRAR:`);
          console.log(`   Host diamonds: ${hostCurrentDiamonds}`);
          console.log(`   Guest diamonds: ${guestCurrentDiamonds}`);
          console.log(`💰 Total pot: ${betAmount * 2} diamantes`);
          console.log(`======================================\n`);

          // Actualizar los balances después del cobro
          transaction.update(hostRef, { diamonds: hostCurrentDiamonds });
          transaction.update(guestRef, { diamonds: guestCurrentDiamonds });

          // Marcar cuotas como cobradas
          transaction.update(gameRef, {
            quotasCollected: true,
            quotasCollectedAt: admin.firestore.FieldValue.serverTimestamp(),
            totalPot: betAmount * 2,
          });

          quotasAlreadyCollected = true;
        } else {
          console.log(`\n✅ Cuotas ya fueron cobradas previamente\n`);
        }

        // PASO 2: CALCULAR Y DISTRIBUIR RECOMPENSAS
        // Comisión: 10% en modo apuesta con diamantes.
        // Math.floor en winnerPrize garantiza que la casa siempre reciba al menos su 10%.
        // houseCommission se calcula como el resto exacto (totalPot - lo que reciben los jugadores).
        const totalPot = betAmount * 2;
        const winnerPrize = betAmount + Math.floor(betAmount * 0.90); // ganador recibe su apuesta + 90% de la contraria
        const drawReturn  = Math.floor(betAmount * 0.90);              // empate: cada uno recupera 90% de su apuesta

        console.log(`\n💵 CÁLCULOS DE RECOMPENSAS (10% comisión):`);
        console.log(`   totalPot: ${totalPot} diamantes`);
        console.log(`   betAmount por jugador: ${betAmount} diamantes`);
        console.log(`   winnerPrize: ${winnerPrize} diamantes`);
        console.log(`   drawReturn: ${drawReturn} diamantes por jugador`);
        console.log(`   houseCommission (win): ${totalPot - winnerPrize} diamantes`);
        console.log(`   houseCommission (draw): ${totalPot - drawReturn * 2} diamantes`);

        let hostReward = 0;
        let guestReward = 0;
        let distributionReason = '';

        if (gameJustAbandoned) {
          distributionReason = 'abandoned';
          if (abandonedBy === hostId) {
            guestReward = winnerPrize;
            console.log(`🚪 Host abandonó → Guest gana ${guestReward} diamantes`);
          } else if (abandonedBy === guestId) {
            hostReward = winnerPrize;
            console.log(`🚪 Guest abandonó → Host gana ${hostReward} diamantes`);
          }
        } else {
          if (result === 'draw') {
            distributionReason = 'draw';
            hostReward  = drawReturn;
            guestReward = drawReturn;
            console.log(`🤝 EMPATE → Cada uno recibe ${drawReturn} diamantes de regreso`);
          } else if (winnerId === hostId) {
            distributionReason = 'host_won';
            hostReward = winnerPrize;
            console.log(`✅ HOST GANÓ → Host recibe ${hostReward} diamantes`);
          } else if (winnerId === guestId) {
            distributionReason = 'guest_won';
            guestReward = winnerPrize;
            console.log(`✅ GUEST GANÓ → Guest recibe ${guestReward} diamantes`);
          }
        }

        const actualHouseCommission = totalPot - hostReward - guestReward;

        // Verificación matemática — nunca debe fallar
        if (actualHouseCommission < 0) {
          throw new Error(`MATH ERROR: houseCommission negativo (${actualHouseCommission}). totalPot=${totalPot}, host=${hostReward}, guest=${guestReward}`);
        }

        console.log(`\n💎 DISTRIBUCIÓN FINAL DE RECOMPENSAS:`);
        console.log(`   Host reward: ${hostReward} diamantes`);
        console.log(`   Guest reward: ${guestReward} diamantes`);
        console.log(`   House commission: ${actualHouseCommission} diamantes (exacto)`);

        // Aplicar las recompensas
        const hostNewDiamonds  = hostCurrentDiamonds  + hostReward;
        const guestNewDiamonds = guestCurrentDiamonds + guestReward;

        console.log(`💎 BALANCES FINALES: Host ${hostCurrentDiamonds}+${hostReward}=${hostNewDiamonds} | Guest ${guestCurrentDiamonds}+${guestReward}=${guestNewDiamonds}`);

        const hostNetGain  = hostReward  - betAmount;
        const guestNetGain = guestReward - betAmount;

        console.log(`📈 NETO: Host ${hostNetGain >= 0 ? '+' : ''}${hostNetGain} | Guest ${guestNetGain >= 0 ? '+' : ''}${guestNetGain}`);

        transaction.update(hostRef, {
          diamonds:       hostNewDiamonds,
          diamondsEarned: (hostData.diamondsEarned  || 0) + Math.max(0, hostNetGain),
        });
        transaction.update(guestRef, {
          diamonds:       guestNewDiamonds,
          diamondsEarned: (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain),
        });

        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            hostReward,
            guestReward,
            houseCommission: actualHouseCommission,
            totalPot,
            betAmount,
            currencyType: 'diamonds',
            commissionRate: 0.10,
            reason: distributionReason,
            abandonedBy: abandonedBy || null,
            hostNetGain,
            guestNetGain,
          },
        });

        console.log(`✅ [${gameId}] Online bet transacción completada | bet:${betAmount} | winner:${winnerPrize} | casa:${actualHouseCommission}\n`);
      });

      return null;
    } catch (error) {
      console.error(`\n❌ ========== ERROR ==========`);
      console.error(`Game ID: ${gameId}`);
      console.error(`Error:`, error);
      console.error(`==============================\n`);
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
    const guestId     = afterData.guest2Id;
    const winnerId    = afterData.winnerId;
    const abandonedBy = afterData.abandonedBy;

    if (!hostId || !guestId) {
      console.log(`❌ [Ludo ${gameId}] Juego sin dos jugadores (SALIENDO)\n`);
      return null;
    }

    console.log(`\n🚀 [Ludo ${gameId}] ¡PROCEDIENDO A DISTRIBUIR!`);
    console.log(`   Tipo: ${gameJustAbandoned ? 'ABANDONO' : 'VICTORIA'}`);

    try {
      await db.runTransaction(async (transaction) => {
        const gameRef  = db.collection('ludo_games').doc(gameId);
        const hostRef  = db.collection('users').doc(hostId);
        const guestRef = db.collection('users').doc(guestId);

        const [hostDoc, guestDoc, gameDoc] = await Promise.all([
          transaction.get(hostRef),
          transaction.get(guestRef),
          transaction.get(gameRef),
        ]);

        if (!hostDoc.exists || !guestDoc.exists) throw new Error('Usuarios no encontrados');

        const currentGameData = gameDoc.data();
        if (currentGameData && currentGameData.rewardsDistributed === true) {
          console.log(`⚠️ [Ludo ${gameId}] Ya distribuido en transacción\n`);
          return;
        }

        const hostData  = hostDoc.data();
        const guestData = guestDoc.data();

        // Las cuotas deben haberse cobrado en el cliente al unirse el guest
        // (igual que en chess). Si no están cobradas, salir.
        if (currentGameData?.quotasCollected !== true) {
          console.log(`⚠️ [Ludo ${gameId}] Cuotas no cobradas (SALIENDO)\n`);
          return;
        }

        const isCoins = currencyType === 'coins';
        // Los balances ya fueron deducidos cuando se cobró la cuota; aquí solo distribuimos premios.
        const hostBalance  = isCoins ? (hostData.coins  || 0) : (hostData.diamonds  || 0);
        const guestBalance = isCoins ? (guestData.coins || 0) : (guestData.diamonds || 0);

        // Apuesta (diamantes): casa cobra 10% del pot → ganador recibe 90% del pot.
        // Diversión (monedas) : casa cobra 30% del pot → ganador recibe 70% del pot.
        const isBetDiamonds = !isCoins && betAmount > 0;
        const pot         = betAmount * 2;
        const winnerPrize = isBetDiamonds
          ? Math.floor(pot * 0.90) // apuesta: ganador recibe 90% del pot
          : Math.floor(pot * 0.70); // diversión: ganador recibe 70% del pot
        // La comisión es el resto exacto del pot para garantizar math exacta.
        const houseCommissionWin = (betAmount * 2) - winnerPrize;

        let hostReward  = 0;
        let guestReward = 0;
        let distributionReason = '';

        if (gameJustAbandoned) {
          distributionReason = 'abandoned';
          if (abandonedBy === hostId)       { guestReward = winnerPrize; console.log(`   ❌ Host abandonó → Guest gana ${guestReward}`); }
          else if (abandonedBy === guestId) { hostReward  = winnerPrize; console.log(`   ❌ Guest abandonó → Host gana ${hostReward}`); }
        } else {
          if (winnerId === hostId)       { distributionReason = 'host_won';  hostReward  = winnerPrize; console.log(`   ✅ Host ganó → ${hostReward}`); }
          else if (winnerId === guestId) { distributionReason = 'guest_won'; guestReward = winnerPrize; console.log(`   ✅ Guest ganó → ${guestReward}`); }
        }

        const actualHouseCommission = (betAmount * 2) - hostReward - guestReward;

        // Verificación matemática
        if (actualHouseCommission < 0) {
          throw new Error(`[Ludo] MATH ERROR: houseCommission negativo (${actualHouseCommission})`);
        }

        const hostNewBalance  = hostBalance  + hostReward;
        const guestNewBalance = guestBalance + guestReward;
        const hostNetGain  = hostReward  - betAmount;
        const guestNetGain = guestReward - betAmount;

        console.log(`💵 [Ludo] bet:${betAmount} | winner:${winnerPrize} | casa:${actualHouseCommission} | comisión:${isBetDiamonds ? '10%' : '30%'}`);
        console.log(`   Host:  ${hostBalance}+${hostReward}=${hostNewBalance} (net:${hostNetGain})`);
        console.log(`   Guest: ${guestBalance}+${guestReward}=${guestNewBalance} (net:${guestNetGain})`);

        if (isCoins) {
          transaction.update(hostRef,  { coins: hostNewBalance });
          transaction.update(guestRef, { coins: guestNewBalance });
        } else {
          transaction.update(hostRef,  { diamonds: hostNewBalance,  diamondsEarned: (hostData.diamondsEarned  || 0) + Math.max(0, hostNetGain) });
          transaction.update(guestRef, { diamonds: guestNewBalance, diamondsEarned: (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain) });
        }
        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            hostReward, guestReward,
            houseCommission: actualHouseCommission,
            totalPot: betAmount * 2, betAmount, currencyType,
            commissionRate: isBetDiamonds ? 0.10 : 0.30,
            reason: distributionReason,
            abandonedBy: abandonedBy || null,
            hostNetGain, guestNetGain,
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
