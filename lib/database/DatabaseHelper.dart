import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import '../AnimalData.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  late DatabaseReference _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal() {
    _database = FirebaseDatabase.instance.reference();
  }

  Future<String> GenerateAndSaveUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = const Uuid().v4();
    await prefs.setString('userId', userId);
    return userId;
  }

  Future<void> InsertAnimal(AnimalData pAnimalData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(pAnimalData.id, pAnimalData.smashValue);

    // Get user ID from SharedPreferences
    String? userId = prefs.getString('userId');

    //TODO: THIS IS COMMENTED OUT SO WE DON'T FLOOD DB WHEN TESTING.

    // Upload data to Firebase
    if (userId != null) {
      await _database
          .child('users')
          .child(userId)
          .child(pAnimalData.id)
          .set(pAnimalData.smashValue);
    }

    Map<String, dynamic> counts =
        (await DatabaseHelper().GetVillagerCounts(pAnimalData.id));

    if (pAnimalData.smashValue == "smash") {
      // Update smash count in the database
      await _database
          .child('villagerTotals')
          .child(pAnimalData.id)
          .child('smashCount')
          .set(counts['smashCount'] + 1);
    } else if (pAnimalData.smashValue == "pass") {
      // Update pass count in the database
      await _database
          .child('villagerTotals')
          .child(pAnimalData.id)
          .child('passCount')
          .set(counts['passCount'] + 1);
    }
  }

  Future<Map<String, String>> GetData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, String> animalDataMap = {};

    prefs.getKeys().forEach((key) {
      animalDataMap[key] = prefs.getString(key)!;
    });

    return animalDataMap;
  }

  Future<void> LogAllSwipedData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> keys = prefs.getKeys();

    for (String key in keys) {
      final String? value = prefs.getString(key);
      if (value != null) {
        print('$key: $value');
      }
    }
  }

  Future<int> GetSmashCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int count = 0;

    final Map<String, String> allSwipedData =
        prefs.getKeys().fold<Map<String, String>>(
      {},
      (map, key) {
        final String swipeValue = prefs.getString(key)!;
        if (swipeValue == 'smash') {
          count++;
        }
        return map;
      },
    );
    return count;
  }

  Future<int> GetPassCount() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int count = 0;

    final Map<String, String> allSwipedData =
        prefs.getKeys().fold<Map<String, String>>(
      {},
      (map, key) {
        final String swipeValue = prefs.getString(key)!;
        if (swipeValue == 'pass') {
          count++;
        }
        return map;
      },
    );
    return count;
  }

  Future<Map<String, dynamic>> GetFirebaseVillagerData() async {
    DataSnapshot? snapshot;
    await _database.child('villagers').once().then((event) {
      if (event.snapshot != null) {
        snapshot = event.snapshot;
      } else {
        // Handle error or return default value
        return {};
      }
    }).catchError((error) {
      // Handle error or return default value
      print('Error: $error');
      return {};
    });

    if (snapshot != null) {
      dynamic data = snapshot!.value;
      if (data != null && data is Map<dynamic, dynamic>) {
        Map<String, dynamic> castedData = {};
        data.forEach((key, value) {
          if (value != null) {
            castedData[key.toString()] = value;
          }
        });
        return castedData;
      }
    }

    // Handle error or return default value
    return {};
  }

  Future<Map<String, dynamic>> GetVillagerCounts(String pVillagerID) async {
    try {
      // Check if the event contains a snapshot
      if ((await _database.child('villagerTotals').child(pVillagerID).once())
                  .snapshot !=
              null &&
          (await _database.child('villagerTotals').child(pVillagerID).once())
                  .snapshot
                  .value !=
              null) {
        Map<dynamic, dynamic> data =
            (await _database.child('villagerTotals').child(pVillagerID).once())
                .snapshot
                .value as Map<dynamic, dynamic>;

        // Ensure both 'Smash amount' and 'Pass amount' keys exist before proceeding
        if (data.containsKey('smashCount') && data.containsKey('passCount')) {
          int smashCount = data['smashCount'] ?? 0;
          int passCount = data['passCount'] ?? 0;

          return {'smashCount': smashCount, 'passCount': passCount};
        }
      }

      // Handle null or unexpected data format
      return {'smashCount': 0, 'passCount': 0};
    } catch (error) {
      // Handle error
      print('Error: $error');
      return {'smashCount': 0, 'passCount': 0};
    }
  }
}
