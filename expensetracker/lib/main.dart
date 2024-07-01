import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';


List<Expense> _list = [];

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
    final db = await database;

    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Expense>> retrieveExpenses() async {
    final db = await database;

    final List<Map<String, Object?>> expenseMaps = await db.query('expenses');

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
    final db = await database;

    await db.delete(
      'expenses',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  _list = await retrieveExpenses();
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
              Column(
                children: [
                  Center(
                      child: ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                            title: Text(_list[index].name),
                            subtitle: Text(_list[index].cost.toString()),
                            leading: Image.memory(
                              base64Decode(_list[index].image),
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            )),
                      );
                    },
                  )),
                ],
              ),
              const Center(child: Text("2º page")),
            ][_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
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
