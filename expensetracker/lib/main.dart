import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = openDatabase(
  
  join(await getDatabasesPath(), 'expenses.db'),
  onCreate: (db, version) {
    
    return db.execute(
      'CREATE TABLE expenses(name TEXT PRIMARY KEY, cost INTEGER, image TEXT)',
    );
  },
  
  version: 1,
  );

  Future<void> insertExpense(Expense expense) async {
  // Get a reference to the database.
  final db = await database;

  // Insert the Dog into the correct table. You might also specify the
  // `conflictAlgorithm` to use in case the same dog is inserted twice.
  //
  // In this case, replace any previous data.
  await db.insert(
    'expenses',
    expense.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Expense>> retrieveExpenses() async {
  // Get a reference to the database.
  final db = await database;

  // Query the table for all the dogs.
  final List<Map<String, Object?>> expenseMaps = await db.query('expenses');

  // Convert the list of each dog's fields into a list of `Dog` objects.
  return [
    for (final {
          'name': name as String,
          'cost': cost as int,
          'image': image as String,
        } in expenseMaps)
      Expense(name: name, cost: cost, image: image),
    ];
  } 
  Future<void> deleteExpense(String name) async {
  // Get a reference to the database.
  final db = await database;

  // Remove the Dog from the database.
  await db.delete(
    'expenses',
    // Use a `where` clause to delete a specific dog.
    where: 'name = ?',
    // Pass the Dog's id as a whereArg to prevent SQL injection.
    whereArgs: [name],
  );
}
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class Expense {
  final String name;
  final int cost;
  final String image;

  const Expense({
    required this.name,
    required this.cost,
    required this.image,
  });

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'cost': cost,
      'image': image,
    };
  }

  // Implement toString to make it easier to see information about
  // each dog when using the print statement.
  @override
  String toString() {
    return 'Expense{name: $name, cost: $cost, image: $image}';
  }
}


class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                "PresuPuest",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
            ),
            body: <Widget>[
              const Center(child: Text("Home Page")),
              const Center(child: Text("2º page")),
            ][_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                  // prefs.setInt('page', index);
                });
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home Page',
                ),
                const NavigationDestination(
                    icon: Icon(Icons.image), label: '2ºpage')
              ],
            ),
          );
        },
      ),
    );
  }
}