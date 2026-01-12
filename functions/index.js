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

  
   // FUNCIÓN: Distribuir recompensas del juego (finished Y abandoned)
exports.distributeGameRewards = onDocumentUpdated(
  {
    document: 'multiplayer_games/{gameId}',
    region: 'us-east1',
  },
  async (event) => {
    const gameId = event.params.gameId;
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    console.log(`\n🎮 [${gameId}] === INICIO FUNCIÓN ===`);
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

    if (afterData.quotasCollected !== true) {
      console.log(`⚠️ [${gameId}] ❌ Cuotas no cobradas (SALIENDO)`);
      console.log(`   Valor actual de quotasCollected: ${afterData.quotasCollected}`);
      return null;
    }

    const winnerId = afterData.winnerId;
    const hostId = afterData.hostId;
    const guestId = afterData.guestId;
    const totalPot = afterData.totalPot || 0;
    const currencyType = afterData.currencyType || 'coins';
    const result = afterData.result;
    const abandonedBy = afterData.abandonedBy;

    if (!guestId || totalPot === 0) {
      console.log(`❌ [${gameId}] Datos insuficientes para distribuir`);
      console.log(`   guestId: ${guestId}, totalPot: ${totalPot}\n`);
      return null;
    }

    console.log(`\n🚀 [${gameId}] ¡PROCEDIENDO A DISTRIBUIR RECOMPENSAS!`);
    console.log(`   Tipo de finalización: ${gameJustAbandoned ? 'ABANDONO' : 'FINISHED'}`);
    console.log(`   Currency Type: ${currencyType}\n`);

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

        const quotaAmount = totalPot / 2;
        const winnerPrize = quotaAmount + Math.round(quotaAmount * 0.7);
        const houseCommission = Math.round(quotaAmount * 0.3);

        console.log(`\n💵 CÁLCULOS INICIALES:`);
        console.log(`   totalPot: ${totalPot}`);
        console.log(`   quotaAmount: ${quotaAmount}`);
        console.log(`   winnerPrize: ${winnerPrize}`);
        console.log(`   houseCommission: ${houseCommission}`);

        let hostReward = 0;
        let guestReward = 0;

        if (gameJustAbandoned) {
          console.log(`\n🚪 Procesando ABANDONO`);
          console.log(`   abandonedBy: ${abandonedBy}`);
          if (abandonedBy === hostId) {
            hostReward = 0;
            guestReward = winnerPrize;
            console.log(`   ❌ Host abandonó → ✅ Guest gana ${winnerPrize}`);
          } else if (abandonedBy === guestId) {
            hostReward = winnerPrize;
            guestReward = 0;
            console.log(`   ✅ Host gana ${hostReward} ← ❌ Guest abandonó`);
          }
        } else {
          console.log(`\n🏁 Procesando JUEGO TERMINADO`);
          console.log(`   result: "${result}"`);
          console.log(`   winnerId: "${winnerId}"`);
          
          if (result === 'draw') {
            const drawReturn = Math.round(quotaAmount * 0.15);
            hostReward = drawReturn;
            guestReward = drawReturn;
            console.log(`   🤝 EMPATE → Cada uno recibe ${drawReturn}`);
          } else if (winnerId === hostId) {
            hostReward = winnerPrize;
            guestReward = 0;
            console.log(`   ✅ HOST GANÓ → Host recibe ${hostReward}, Guest ${guestReward}`);
          } else if (winnerId === guestId) {
            hostReward = 0;
            guestReward = winnerPrize;
            console.log(`   ✅ GUEST GANÓ → Guest recibe ${guestReward}, Host ${hostReward}`);
          }
        }

        console.log(`\n💵 DISTRIBUCIÓN FINAL:`);
        console.log(`   Host reward: ${hostReward}`);
        console.log(`   Guest reward: ${guestReward}`);
        console.log(`   House commission: ${houseCommission}`);
        
    
        if (currencyType === 'coins') {
          const hostOldCoins = hostData.coins || 0;
          const guestOldCoins = guestData.coins || 0;
          
          const hostNewCoins = hostOldCoins + hostReward;
          const guestNewCoins = guestOldCoins + guestReward;

          console.log(`\n💰 ========== MONEDAS ==========`);
          console.log(`📊 ANTES DE DISTRIBUIR:`);
          console.log(`   Host: ${hostOldCoins} monedas`);
          console.log(`   Guest: ${guestOldCoins} monedas`);
          console.log(`💵 RECOMPENSAS A DISTRIBUIR:`);
          console.log(`   Host recibe: +${hostReward} monedas`);
          console.log(`   Guest recibe: +${guestReward} monedas`);
          console.log(`📊 DESPUÉS DE DISTRIBUIR:`);
          console.log(`   Host: ${hostNewCoins} monedas (${hostOldCoins} + ${hostReward})`);
          console.log(`   Guest: ${guestNewCoins} monedas (${guestOldCoins} + ${guestReward})`);
          console.log(`===============================\n`);

      
          transaction.update(hostRef, { coins: hostNewCoins });
          transaction.update(guestRef, { coins: guestNewCoins });
          
        } else {
      
          const hostOldDiamonds = hostData.diamonds || 0;
          const guestOldDiamonds = guestData.diamonds || 0;
          
          const hostNewDiamonds = hostOldDiamonds + hostReward;
          const guestNewDiamonds = guestOldDiamonds + guestReward;
          
          console.log(`\n💎 ========== DIAMANTES (APUESTA) ==========`);
          console.log(`📊 ANTES DE DISTRIBUIR:`);
          console.log(`   Host ID: ${hostId}`);
          console.log(`   Host: ${hostOldDiamonds} diamantes`);
          console.log(`   Guest ID: ${guestId}`);
          console.log(`   Guest: ${guestOldDiamonds} diamantes`);
          console.log(`💵 RECOMPENSAS A DISTRIBUIR:`);
          console.log(`   Host recibe: +${hostReward} diamantes`);
          console.log(`   Guest recibe: +${guestReward} diamantes`);
          console.log(`📊 DESPUÉS DE DISTRIBUIR:`);
          console.log(`   Host: ${hostNewDiamonds} diamantes (${hostOldDiamonds} + ${hostReward})`);
          console.log(`   Guest: ${guestNewDiamonds} diamantes (${guestOldDiamonds} + ${guestReward})`);
          
          // Calcular ganancias netas para tracking
          const hostNetGain = hostReward - quotaAmount;
          const guestNetGain = guestReward - quotaAmount;
          
          console.log(`📈 GANANCIAS NETAS:`);
          console.log(`   Host: ${hostNetGain > 0 ? '+' : ''}${hostNetGain} diamantes`);
          console.log(`   Guest: ${guestNetGain > 0 ? '+' : ''}${guestNetGain} diamantes`);
          
          const hostNewDiamondsEarned = (hostData.diamondsEarned || 0) + Math.max(0, hostNetGain);
          const guestNewDiamondsEarned = (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain);
          
          console.log(`💰 DIAMANTES GANADOS TOTALES:`);
          console.log(`   Host: ${hostNewDiamondsEarned} (anterior: ${hostData.diamondsEarned || 0})`);
          console.log(`   Guest: ${guestNewDiamondsEarned} (anterior: ${guestData.diamondsEarned || 0})`);
          console.log(`==========================================\n`);

      
          transaction.update(hostRef, { 
            diamonds: hostNewDiamonds,
            diamondsEarned: hostNewDiamondsEarned
          });
          transaction.update(guestRef, { 
            diamonds: guestNewDiamonds,
            diamondsEarned: guestNewDiamondsEarned
          });
        }

        // Actualizar documento del juego
        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            hostReward,
            guestReward,
            houseCommission,
            currencyType,
            reason: gameJustAbandoned ? 'abandoned' : 'finished',
            abandonedBy: abandonedBy || null,
          },
        });

        console.log(`\n✅ ========== TRANSACCIÓN COMPLETADA ==========`);
        console.log(`   Game ID: ${gameId}`);
        console.log(`   Razón: ${gameJustAbandoned ? 'ABANDONO' : 'FINISHED'}`);
        console.log(`   Currency: ${currencyType}`);
        console.log(`   Host reward: ${hostReward} ${currencyType}`);
        console.log(`   Guest reward: ${guestReward} ${currencyType}`);
        console.log(`   House commission: ${houseCommission} ${currencyType}`);
        console.log(`============================================\n`);
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
        const totalPot = betAmount * 2;
        const winnerPrize = betAmount + Math.round(betAmount * 0.7);
        const houseCommission = Math.round(betAmount * 0.3);

        console.log(`\n💵 CÁLCULOS DE RECOMPENSAS:`);
        console.log(`   totalPot: ${totalPot} diamantes`);
        console.log(`   betAmount por jugador: ${betAmount} diamantes`);
        console.log(`   winnerPrize: ${winnerPrize} diamantes`);
        console.log(`   houseCommission: ${houseCommission} diamantes (30%)`);

        let hostReward = 0;
        let guestReward = 0;
        let distributionReason = '';

        if (gameJustAbandoned) {
          console.log(`\n🚪 Procesando ABANDONO`);
          console.log(`   abandonedBy: ${abandonedBy}`);
          distributionReason = 'abandoned';
          
          if (abandonedBy === hostId) {
            guestReward = winnerPrize;
            console.log(`   ❌ Host abandonó → ✅ Guest gana ${guestReward} diamantes`);
          } else if (abandonedBy === guestId) {
            hostReward = winnerPrize;
            console.log(`   ✅ Host gana ${hostReward} diamantes ← ❌ Guest abandonó`);
          }
        } else {
          console.log(`\n🏁 Procesando JUEGO TERMINADO`);
          console.log(`   result: "${result}"`);
          console.log(`   winnerId: "${winnerId}"`);
          
          if (result === 'draw') {
            distributionReason = 'draw';
            const drawReturn = Math.round(betAmount * 0.15);
            hostReward = drawReturn;
            guestReward = drawReturn;
            console.log(`   🤝 EMPATE → Cada uno recibe ${drawReturn} diamantes de regreso`);
          } else if (winnerId === hostId) {
            distributionReason = 'host_won';
            hostReward = winnerPrize;
            console.log(`   ✅ HOST GANÓ → Host recibe ${hostReward} diamantes`);
          } else if (winnerId === guestId) {
            distributionReason = 'guest_won';
            guestReward = winnerPrize;
            console.log(`   ✅ GUEST GANÓ → Guest recibe ${guestReward} diamantes`);
          }
        }

        console.log(`\n💎 DISTRIBUCIÓN FINAL DE RECOMPENSAS:`);
        console.log(`   Host reward: ${hostReward} diamantes`);
        console.log(`   Guest reward: ${guestReward} diamantes`);
        console.log(`   House commission: ${houseCommission} diamantes`);

        // Aplicar las recompensas
        const hostNewDiamonds = hostCurrentDiamonds + hostReward;
        const guestNewDiamonds = guestCurrentDiamonds + guestReward;

        console.log(`\n💎 ========== APLICANDO RECOMPENSAS ==========`);
        console.log(`📊 BALANCES FINALES:`);
        console.log(`   Host: ${hostCurrentDiamonds} + ${hostReward} = ${hostNewDiamonds} diamantes`);
        console.log(`   Guest: ${guestCurrentDiamonds} + ${guestReward} = ${guestNewDiamonds} diamantes`);

        // Calcular ganancias NETAS (recompensa - cuota pagada)
        const hostNetGain = hostReward - betAmount;
        const guestNetGain = guestReward - betAmount;

        console.log(`\n📈 GANANCIAS NETAS (recompensa - cuota):`);
        console.log(`   Host: ${hostNetGain > 0 ? '+' : ''}${hostNetGain} diamantes`);
        console.log(`   Guest: ${guestNetGain > 0 ? '+' : ''}${guestNetGain} diamantes`);

        // Actualizar diamondsEarned SOLO si ganaron dinero
        const hostNewDiamondsEarned = (hostData.diamondsEarned || 0) + Math.max(0, hostNetGain);
        const guestNewDiamondsEarned = (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain);

        console.log(`\n💰 DIAMANTES GANADOS TOTALES (acumulado):`);
        console.log(`   Host: ${hostNewDiamondsEarned} (anterior: ${hostData.diamondsEarned || 0})`);
        console.log(`   Guest: ${guestNewDiamondsEarned} (anterior: ${guestData.diamondsEarned || 0})`);
        console.log(`============================================\n`);

        // Actualizar usuarios
        transaction.update(hostRef, {
          diamonds: hostNewDiamonds,
          diamondsEarned: hostNewDiamondsEarned,
        });
        transaction.update(guestRef, {
          diamonds: guestNewDiamonds,
          diamondsEarned: guestNewDiamondsEarned,
        });

        // Actualizar documento del juego
        transaction.update(gameRef, {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: {
            hostReward,
            guestReward,
            houseCommission,
            totalPot,
            betAmount,
            currencyType: 'diamonds',
            reason: distributionReason,
            abandonedBy: abandonedBy || null,
            hostNetGain,
            guestNetGain,
          },
        });

        console.log(`\n✅ ========== TRANSACCIÓN COMPLETADA ==========`);
        console.log(`   Game ID: ${gameId}`);
        console.log(`   Razón: ${distributionReason}`);
        console.log(`   Bet Amount: ${betAmount} diamantes`);
        console.log(`   Total Pot: ${totalPot} diamantes`);
        console.log(`   Host reward: ${hostReward} diamantes (net: ${hostNetGain})`);
        console.log(`   Guest reward: ${guestReward} diamantes (net: ${guestNetGain})`);
        console.log(`   House commission: ${houseCommission} diamantes`);
        console.log(`===============================================\n`);
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