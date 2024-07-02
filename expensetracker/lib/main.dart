import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Expense> _list = [];
var database;
int balance = 0;
var prefs;

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
  prefs = await SharedPreferences.getInstance();
  _list = await retrieveExpenses();
  balance = prefs.getInt("balance") ?? 0;
  updateBalance();
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

void updateBalance() async {
  int tempBalance = 0;
  for (int i = 0; i < _list.length; i++) {
    tempBalance -= _list[i].cost;
  }
  if (balance != tempBalance) {
    balance = tempBalance;

    await prefs.setInt('balance', balance);
  }
}

class _MyAppState extends State<MyApp> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String name = "";
  int cost = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
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
            body: Column(
              children: [
                Stack(children: [
                  Padding(
                      padding: EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text("${balance.toString()}€",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 75,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 4
                                  ..color = Colors.black)),
                      )),
                  Padding(
                      padding: EdgeInsets.all(20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text("${balance.toString()}€",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 75,
                                color: balance < 0
                                    ? Colors.redAccent
                                    : Colors.green)),
                      )),
                ]),
                Container(
                  height: 520,
                  child: Center(
                      child: Card(
                    elevation: 0,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
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
                    ),
                  )),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: FloatingActionButton(
                        shape: CircleBorder(),
                        onPressed: () {
                          showModalBottomSheet(
                              context: context,
                              builder: (BuildContext context) {
                                return SizedBox(
                                    height: 200,
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: FloatingActionButton(
                                                    child:
                                                        Icon(Icons.money_sharp),
                                                    onPressed: () {
                                                      showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                              context) {
                                                            return AlertDialog(
                                                              title: Text(
                                                                  "Add balance"),
                                                              content:
                                                                  Container(
                                                                height: 150,
                                                                child: Column(
                                                                  children: [
                                                                    Text(
                                                                        "Input added balance"),
                                                                    TextField(
                                                                      decoration:
                                                                          InputDecoration(
                                                                        border:
                                                                            OutlineInputBorder(),
                                                                        labelText:
                                                                            "Amount of balance",
                                                                      ),
                                                                      onChanged:
                                                                          (value) {
                                                                        setState(
                                                                            () {
                                                                          cost =
                                                                              int.parse(value);
                                                                        });
                                                                      },
                                                                      keyboardType:
                                                                          TextInputType
                                                                              .number,
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                              actions: [
                                                                ElevatedButton(
                                                                    onPressed:
                                                                        () {
                                                                      setState(
                                                                          () {
                                                                        balance +=
                                                                            cost;
                                                                        prefs.setInt(
                                                                            'balance',
                                                                            balance);
                                                                      });
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                    },
                                                                    child: Text(
                                                                        "Save"))
                                                              ],
                                                            );
                                                          });
                                                    }),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text("Add Balance"),
                                              )
                                            ],
                                          ),
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: FloatingActionButton(
                                                    child: Icon(Icons.shop),
                                                    onPressed: () {
                                                      showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                                  context) =>
                                                              AlertDialog(
                                                                title: Text(
                                                                    "Input expenses"),
                                                                content:
                                                                    Container(
                                                                  height: 260,
                                                                  child: Column(
                                                                    children: [
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            2.0),
                                                                        child: Center(
                                                                            child: SizedBox(
                                                                          height:
                                                                              75,
                                                                          width:
                                                                              75,
                                                                          child: _image == null
                                                                              ? const Center(child: Text('No Image selected'))
                                                                              : Image.file(
                                                                                  _image!,
                                                                                  fit: BoxFit.contain,
                                                                                ),
                                                                        )),
                                                                      ),
                                                                      ElevatedButton(
                                                                          onPressed:
                                                                              () async {
                                                                            var pickedFile =
                                                                                await _picker.pickImage(source: ImageSource.gallery);
                                                                            if (pickedFile !=
                                                                                null) {
                                                                              setState(() {
                                                                                _image = File(pickedFile.path);
                                                                              });
                                                                            }
                                                                          },
                                                                          child:
                                                                              Text("Pick image")),
                                                                      Padding(
                                                                        padding:
                                                                            EdgeInsets.all(5),
                                                                        child:
                                                                            TextField(
                                                                          decoration:
                                                                              InputDecoration(
                                                                            border:
                                                                                OutlineInputBorder(),
                                                                            labelText:
                                                                                "Name of expense",
                                                                          ),
                                                                          onChanged:
                                                                              (value) {
                                                                            name =
                                                                                value;
                                                                          },
                                                                        ),
                                                                      ),
                                                                      Padding(
                                                                        padding:
                                                                            EdgeInsets.all(5),
                                                                        child:
                                                                            TextField(
                                                                          decoration:
                                                                              InputDecoration(
                                                                            border:
                                                                                OutlineInputBorder(),
                                                                            labelText:
                                                                                "Cost of expense",
                                                                          ),
                                                                          onChanged:
                                                                              (value) {
                                                                            cost =
                                                                                int.parse(value);
                                                                          },
                                                                          keyboardType:
                                                                              TextInputType.number,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  Padding(
                                                                    padding:
                                                                        EdgeInsets.all(
                                                                            25),
                                                                    child: ElevatedButton(
                                                                        onPressed: () async {
                                                                          insertExpense(Expense(
                                                                              name: name,
                                                                              cost: cost,
                                                                              image: base64Encode(await _image!.readAsBytes())));

                                                                          _list =
                                                                              await retrieveExpenses();

                                                                          setState(
                                                                              () {
                                                                            updateBalance();
                                                                            cost =
                                                                                0;
                                                                            name =
                                                                                "";
                                                                          });
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        },
                                                                        child: Text("Save")),
                                                                  ),
                                                                ],
                                                              ));
                                                    }),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text("Add Expense"),
                                              )
                                            ],
                                          ),
                                        ]));
                              });
                          /**/
                        },
                        child: Icon(Icons.add)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
