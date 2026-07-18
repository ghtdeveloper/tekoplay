import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnonymousWalletService {
  static final AnonymousWalletService _instance = AnonymousWalletService._internal();

  factory AnonymousWalletService() => _instance;

  AnonymousWalletService._internal();

  static const String _coinsKey = 'anonymous_coins';
  static const String _diamondsKey = 'anonymous_diamonds';
  static const String _hasTransferredKey = 'has_transferred_wallet';


  Future<int> getAnonymousCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_coinsKey) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo monedas anónimas: $e');
      }
      return 0;
    }
  }

  /// Obtiene los diamantes del usuario anónimo desde SharedPreferences
  Future<int> getAnonymousDiamonds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_diamondsKey) ?? 0; // 0 diamantes iniciales por defecto
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo diamantes anónimos: $e');
      }
      return 0;
    }
  }

  /// Actualiza las monedas del usuario anónimo
  Future<bool> updateAnonymousCoins(int newCoins) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_coinsKey, newCoins);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error actualizando monedas anónimas: $e');
      }
      return false;
    }
  }

  /// Actualiza los diamantes del usuario anónimo
  Future<bool> updateAnonymousDiamonds(int newDiamonds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_diamondsKey, newDiamonds);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error actualizando diamantes anónimos: $e');
      }
      return false;
    }
  }

  /// Añade monedas al usuario anónimo
  Future<bool> addAnonymousCoins(int coinsToAdd) async {
    try {
      final currentCoins = await getAnonymousCoins();
      return await updateAnonymousCoins(currentCoins + coinsToAdd);
    } catch (e) {
      if (kDebugMode) {
        print('Error añadiendo monedas anónimas: $e');
      }
      return false;
    }
  }

  /// Añade diamantes al usuario anónimo
  Future<bool> addAnonymousDiamonds(int diamondsToAdd) async {
    try {
      final currentDiamonds = await getAnonymousDiamonds();
      return await updateAnonymousDiamonds(currentDiamonds + diamondsToAdd);
    } catch (e) {
      if (kDebugMode) {
        print('Error añadiendo diamantes anónimos: $e');
      }
      return false;
    }
  }

  /// Resta monedas del usuario anónimo (para apuestas, etc.)
  Future<bool> subtractAnonymousCoins(int coinsToSubtract) async {
    try {
      final currentCoins = await getAnonymousCoins();
      final newCoins = (currentCoins - coinsToSubtract).clamp(0, double.infinity).toInt();
      return await updateAnonymousCoins(newCoins);
    } catch (e) {
      if (kDebugMode) {
        print('Error restando monedas anónimas: $e');
      }
      return false;
    }
  }

  /// Resta diamantes del usuario anónimo (para apuestas, etc.)
  Future<bool> subtractAnonymousDiamonds(int diamondsToSubtract) async {
    try {
      final currentDiamonds = await getAnonymousDiamonds();
      final newDiamonds = (currentDiamonds - diamondsToSubtract).clamp(0, double.infinity).toInt();
      return await updateAnonymousDiamonds(newDiamonds);
    } catch (e) {
      if (kDebugMode) {
        print('Error restando diamantes anónimos: $e');
      }
      return false;
    }
  }

  /// Verifica si el usuario tiene suficientes monedas
  Future<bool> hasEnoughCoins(int requiredCoins) async {
    final currentCoins = await getAnonymousCoins();
    return currentCoins >= requiredCoins;
  }

  /// Verifica si el usuario tiene suficientes diamantes
  Future<bool> hasEnoughDiamonds(int requiredDiamonds) async {
    final currentDiamonds = await getAnonymousDiamonds();
    return currentDiamonds >= requiredDiamonds;
  }

  /// Transfiere la wallet del usuario anónimo a su cuenta autenticada
  Future<bool> transferAnonymousWalletToUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar si ya se transfirió anteriormente
      final hasTransferred = prefs.getBool(_hasTransferredKey) ?? false;
      if (hasTransferred) {
        if (kDebugMode) {
          print('La wallet anónima ya fue transferida anteriormente');
        }
        return true;
      }

      // Obtener monedas y diamantes actuales del usuario anónimo
      final anonymousCoins = await getAnonymousCoins();
      final anonymousDiamonds = await getAnonymousDiamonds();

      // Solo transferir si hay algo que transferir
      if (anonymousCoins <= 500 && anonymousDiamonds <= 0) {
        if (kDebugMode) {
          print('No hay recursos significativos para transferir');
        }
        await prefs.setBool(_hasTransferredKey, true);
        return true;
      }

      // Obtener los datos actuales del usuario en Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        if (kDebugMode) print('Usuario no encontrado en Firestore');
        return false;
      }

      final userData = userDoc.data()!;
      final currentCoins = userData['coins'] as int? ?? 0;
      final currentDiamonds = userData['diamonds'] as int? ?? 0;

      // Calcular los nuevos totales (solo agregar lo extra de las monedas iniciales)
      final coinsToTransfer = anonymousCoins > 500 ? anonymousCoins - 500 : 0;
      final newCoins = currentCoins + coinsToTransfer + 500; // Dar las 500 iniciales si no las tiene
      final newDiamonds = currentDiamonds + anonymousDiamonds;

      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'coins': newCoins,
        'diamonds': newDiamonds,
        'transferredAt': FieldValue.serverTimestamp(),
      });

      // Marcar como transferido
      await prefs.setBool(_hasTransferredKey, true);

      // Limpiar datos anónimos
      await _clearAnonymousWallet();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error transfiriendo wallet anónima: $e');
      }
      return false;
    }
  }

  /// Limpia los datos de la wallet anónima
  Future<void> _clearAnonymousWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_coinsKey);
      await prefs.remove(_diamondsKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando wallet anónima: $e');
      }
    }
  }

  /// Resetea el flag de transferencia (útil para testing o casos especiales)
  Future<void> resetTransferFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasTransferredKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error reseteando flag de transferencia: $e');
      }
    }
  }

  /// Obtiene el estado completo de la wallet anónima
  Future<Map<String, dynamic>> getAnonymousWalletStatus() async {
    return {
      'coins': await getAnonymousCoins(),
      'diamonds': await getAnonymousDiamonds(),
      'hasTransferred': (await SharedPreferences.getInstance()).getBool(_hasTransferredKey) ?? false,
    };
  }

  /// Inicializa la wallet anónima con valores por defecto si es la primera vez
  Future<void> initializeAnonymousWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Solo inicializar si no existen valores previos
      if (!prefs.containsKey(_coinsKey)) {
        await prefs.setInt(_coinsKey, 500); // 500 monedas iniciales
      }

      if (!prefs.containsKey(_diamondsKey)) {
        await prefs.setInt(_diamondsKey, 0); // 0 diamantes iniciales
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando wallet anónima: $e');
      }
    }
  }

  /// Obtiene las monedas según el estado del usuario (anónimo o autenticado)
  Future<int> getCurrentUserCoins(User? user) async {
    if (user == null) {
      return await getAnonymousCoins();
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          return userData['coins'] as int? ?? 0;
        }
        return 0;
      } catch (e) {
        if (kDebugMode) {
          print('Error obteniendo monedas del usuario: $e');
        }
        return 0;
      }
    }
  }

  /// Obtiene los diamantes según el estado del usuario (anónimo o autenticado)
  Future<int> getCurrentUserDiamonds(User? user) async {
    if (user == null) {
      return await getAnonymousDiamonds();
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          return userData['diamonds'] as int? ?? 0;
        }
        return 0;
      } catch (e) {
        if (kDebugMode) {
          print('Error obteniendo diamantes del usuario: $e');
        }
        return 0;
      }
    }
  }
}