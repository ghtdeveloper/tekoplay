const {setGlobalOptions} = require("firebase-functions/v2/options");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();


setGlobalOptions({ 
  maxInstances: 10,
  region: 'us-east1'
});


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
     
        const winnerPrize = quotaAmount + Math.ceil(quotaAmount * 0.7);
        const houseCommission = Math.ceil(quotaAmount * 0.3);

        console.log(`\n💵 CÁLCULOS INICIALES:`);
        console.log(`   totalPot: ${totalPot}`);
        console.log(`   quotaAmount: ${quotaAmount}`);
        console.log(`   winnerPrize: ${winnerPrize} (quota + ${Math.ceil(quotaAmount * 0.7)})`);
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
         
            const drawReturn = Math.ceil(quotaAmount * 0.15);
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

   
    if (afterData.currencyType !== 'diamonds') {
      console.log(`⏭️ [${gameId}] No es juego de apuesta con diamantes (SALIENDO)`);
      return null;
    }

  
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

         
          if (hostCurrentDiamonds < betAmount) {
            throw new Error(`Host no tiene suficientes diamantes: ${hostCurrentDiamonds} < ${betAmount}`);
          }
          if (guestCurrentDiamonds < betAmount) {
            throw new Error(`Guest no tiene suficientes diamantes: ${guestCurrentDiamonds} < ${betAmount}`);
          }

         
          hostCurrentDiamonds -= betAmount;
          guestCurrentDiamonds -= betAmount;

          console.log(`📊 DESPUÉS DE COBRAR:`);
          console.log(`   Host diamonds: ${hostCurrentDiamonds}`);
          console.log(`   Guest diamonds: ${guestCurrentDiamonds}`);
          console.log(`💰 Total pot: ${betAmount * 2} diamantes`);
          console.log(`======================================\n`);

        
          transaction.update(hostRef, { diamonds: hostCurrentDiamonds });
          transaction.update(guestRef, { diamonds: guestCurrentDiamonds });

         
          transaction.update(gameRef, {
            quotasCollected: true,
            quotasCollectedAt: admin.firestore.FieldValue.serverTimestamp(),
            totalPot: betAmount * 2,
          });

          quotasAlreadyCollected = true;
        } else {
          console.log(`\n✅ Cuotas ya fueron cobradas previamente\n`);
        }

      
        const totalPot = betAmount * 2;
   
        const winnerPrize = betAmount + Math.ceil(betAmount * 0.7);
        const houseCommission = Math.ceil(betAmount * 0.3);

        console.log(`\n💵 CÁLCULOS DE RECOMPENSAS:`);
        console.log(`   totalPot: ${totalPot} diamantes`);
        console.log(`   betAmount por jugador: ${betAmount} diamantes`);
        console.log(`   winnerPrize: ${winnerPrize} diamantes (${betAmount} + ${Math.ceil(betAmount * 0.7)})`);
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
          
            const drawReturn = Math.ceil(betAmount * 0.15);
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

      
        const hostNewDiamonds = hostCurrentDiamonds + hostReward;
        const guestNewDiamonds = guestCurrentDiamonds + guestReward;

        console.log(`\n💎 ========== APLICANDO RECOMPENSAS ==========`);
        console.log(`📊 BALANCES FINALES:`);
        console.log(`   Host: ${hostCurrentDiamonds} + ${hostReward} = ${hostNewDiamonds} diamantes`);
        console.log(`   Guest: ${guestCurrentDiamonds} + ${guestReward} = ${guestNewDiamonds} diamantes`);

      
        const hostNetGain = hostReward - betAmount;
        const guestNetGain = guestReward - betAmount;

        console.log(`\n📈 GANANCIAS NETAS (recompensa - cuota):`);
        console.log(`   Host: ${hostNetGain > 0 ? '+' : ''}${hostNetGain} diamantes`);
        console.log(`   Guest: ${guestNetGain > 0 ? '+' : ''}${guestNetGain} diamantes`);

      
        const hostNewDiamondsEarned = (hostData.diamondsEarned || 0) + Math.max(0, hostNetGain);
        const guestNewDiamondsEarned = (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain);

        console.log(`\n💰 DIAMANTES GANADOS TOTALES (acumulado):`);
        console.log(`   Host: ${hostNewDiamondsEarned} (anterior: ${hostData.diamondsEarned || 0})`);
        console.log(`   Guest: ${guestNewDiamondsEarned} (anterior: ${guestData.diamondsEarned || 0})`);
        console.log(`============================================\n`);

    
        transaction.update(hostRef, {
          diamonds: hostNewDiamonds,
          diamondsEarned: hostNewDiamondsEarned,
        });
        transaction.update(guestRef, {
          diamonds: guestNewDiamonds,
          diamondsEarned: guestNewDiamondsEarned,
        });

    
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

        const isCoins = currencyType === 'coins';
        let hostBalance  = isCoins ? (hostData.coins  || 0) : (hostData.diamonds  || 0);
        let guestBalance = isCoins ? (guestData.coins || 0) : (guestData.diamonds || 0);

        if (currentGameData?.quotasCollected !== true) {
          const symbol = isCoins ? '🪙' : '💎';
          console.log(`\n💰 Cobrando cuotas (${betAmount} ${symbol} c/u)...`);
          if (hostBalance < betAmount)  throw new Error(`Host sin fondos: ${hostBalance} < ${betAmount}`);
          if (guestBalance < betAmount) throw new Error(`Guest sin fondos: ${guestBalance} < ${betAmount}`);
          hostBalance  -= betAmount;
          guestBalance -= betAmount;
          transaction.update(gameRef, {
            quotasCollected: true,
            totalPot: betAmount * 2,
            quotasCollectedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        const winnerPrize     = betAmount + Math.ceil(betAmount * 0.7);
        const houseCommission = Math.ceil(betAmount * 0.3);
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

        const hostNewBalance  = hostBalance  + hostReward;
        const guestNewBalance = guestBalance + guestReward;
        const hostNetGain  = hostReward  - betAmount;
        const guestNetGain = guestReward - betAmount;

        if (isCoins) {
          transaction.update(hostRef,  { coins: hostNewBalance });
          transaction.update(guestRef, { coins: guestNewBalance });
        } else {
          transaction.update(hostRef,  { diamonds: hostNewBalance,  diamondsEarned: (hostData.diamondsEarned  || 0) + Math.max(0, hostNetGain) });
          transaction.update(guestRef, { diamonds: guestNewBalance, diamondsEarned: (guestData.diamondsEarned || 0) + Math.max(0, guestNetGain) });
        }
        transaction.update(gameRef,  {
          rewardsDistributed: true,
          rewardsDistributedAt: admin.firestore.FieldValue.serverTimestamp(),
          distribution: { hostReward, guestReward, houseCommission, totalPot: betAmount * 2, betAmount, currencyType, reason: distributionReason, abandonedBy: abandonedBy || null, hostNetGain, guestNetGain },
        });

        console.log(`\n✅ [Ludo ${gameId}] Distribución completada:`);
        console.log(`   Host:  ${hostDiamonds} + ${hostReward} = ${hostNewDiamonds} 💎 (net: ${hostNetGain})`);
        console.log(`   Guest: ${guestDiamonds} + ${guestReward} = ${guestNewDiamonds} 💎 (net: ${guestNetGain})`);
        console.log(`   Casa:  ${houseCommission} 💎\n`);
      });

      return null;
    } catch (error) {
      console.error(`\n❌ [Ludo ${gameId}] ERROR:`, error);
      throw error;
    }
  }
);
