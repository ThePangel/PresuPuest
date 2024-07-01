import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

List<Expense> _list = [];
var database;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  database = openDatabase(
    join(await getDatabasesPath(), 'expenses.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE expenses(name TEXT PRIMARY KEY, cost INTEGER, image TEXT)',
      );
    },
    version: 1,
  );

  _list = await retrieveExpenses();
  runApp(const MyApp());
}

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

Future<void> updateExpense(Expense expense) async {
  final db = await database;

  await db.update(
    'expenses',
    expense.toMap(),
    where: 'name = ?',
    whereArgs: [expense.name],
  );
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
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String name = "";
  int cost = 0;
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

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
                  Container(
                    height: 500,
                    child: Center(
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
                  ),
                  ElevatedButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                                title: Text("Input expenses"),
                                content: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Center(
                                          child: SizedBox(
                                        height: 150,
                                        width: 500,
                                        child: _image == null
                                            ? const Center(
                                                child:
                                                    Text('No Image selected'))
                                            : Image.file(
                                                _image!,
                                                fit: BoxFit.contain,
                                              ),
                                      )),
                                    ),
                                    ElevatedButton(
                                        onPressed: () async {
                                          var pickedFile =
                                              await _picker.pickImage(
                                                  source: ImageSource.gallery);
                                          if (pickedFile != null) {
                                            setState(() {
                                              _image = File(pickedFile.path);
                                            });
                                          }
                                        },
                                        child: Text("Pick image")),
                                    TextField(
                                      controller: _controller1,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: "Name of expense",
                                      ),
                                      onEditingComplete: () {
                                        name = _controller1.text;
                                        print(name);
                                      },
                                    ),
                                    TextField(
                                      controller: _controller2,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: "Cost of expense",
                                      ),
                                      onEditingComplete: () {
                                        cost = int.parse(_controller2.text);
                                      },
                                    ),
                                    ElevatedButton(
                                        onPressed: () async {
                                          insertExpense(Expense(
                                              name: name,
                                              cost: cost,
                                              image: base64Encode(await _image!
                                                  .readAsBytes())));

                                          _list = await retrieveExpenses();
                                          setState(() {
                                            cost = 0;
                                            name = "";
                                          });
                                        },
                                        child: Text("Save"))
                                  ],
                                )));
                      },
                      child: Text("yes"))
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
