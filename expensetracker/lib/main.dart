import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

List<Expense> _list = [];
List<Expense> _listCopy = [];
var database;
double balance = 0;
var prefs;

enum Item { edit, delete }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  database = openDatabase(
    join(await getDatabasesPath(), 'expenses.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE expenses(name TEXT PRIMARY KEY, cost REAL, image TEXT, date TEXT)',
      );
    },
    version: 1,
  );
  prefs = await SharedPreferences.getInstance();
  _list = await retrieveExpenses();
  _listCopy = _list;
  balance = prefs.getDouble("balance") ?? 0;
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
          'cost': cost as double,
          'image': image as String,
          'date': date as String,
        } in expenseMaps)
      Expense(name: name, cost: cost, image: image, date: date),
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

Future<void> updateExpense(Expense expense, String name) async {
  final db = await database;

  await db.update(
    'expenses',
    expense.toMap(),
    where: 'name = ?',
    whereArgs: [name],
  );
}

Future<Expense> retrieveSingleExpense(String name) async {
  final db = await database;

  final List<Map<String, Object?>> result = await db.query(
    'expenses',
    where: 'name = ?',
    whereArgs: [name],
  );

  final Map<String, Object?> expenseMap = result.first;

  return Expense(
    name: expenseMap['name'] as String,
    cost: expenseMap['cost'] as double, // Convert cost to String if needed
    image: expenseMap['image'] as String,
    date: expenseMap['date'] as String,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class Expense {
  final String name;
  final double cost;
  final String image;
  final String date;

  const Expense({
    required this.name,
    required this.cost,
    required this.image,
    required this.date,
  });

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'cost': cost,
      'image': image,
      'date': date,
    };
  }

  @override
  String toString() {
    return 'Expense{name: $name, cost: $cost, image: $image, date: $date}';
  }
}

void updateBalance() async {
  await prefs.setDouble('balance', double.parse(balance.toStringAsFixed(2)));
}

class _MyAppState extends State<MyApp> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String name = "";
  double cost = 0;
  TextEditingController editingController = TextEditingController();
  TextEditingController _controller = TextEditingController();
  TextEditingController _controller2 = TextEditingController();

  void search(String query) {
    setState(() {
      _list = _listCopy
          .where(
              (item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

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
                        child: Text("${balance.toStringAsFixed(2)}€",
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
                        child: Text("${balance.toStringAsFixed(2)}€",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 75,
                                color: balance < 0
                                    ? Colors.redAccent
                                    : Colors.green)),
                      )),
                ]),
                Container(
                    width: 300,
                    child: TextField(
                      controller: editingController,
                      decoration: InputDecoration(
                          labelText: "Search",
                          hintText: "Search",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(25.0)))),
                      onChanged: (value) => search(value),
                    )),
                Container(
                  height: 420,
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
                              subtitle: Text(
                                  "${_list[index].cost.toString()} \n${_list[index].date}"),
                              isThreeLine: true,
                              trailing: PopupMenuButton(
                                onSelected: (Item item) async {
                                  Expense temp = await retrieveSingleExpense(
                                      _list[index].name);
                                  _controller.text = temp.name;
                                  _controller2.text = temp.cost.toString();
                                  name = temp.name;
                                  cost = temp.cost;
                                  setState(() {
                                    if (item == Item.edit) {
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext context) =>
                                              AlertDialog(
                                                title: Text("Input expenses"),
                                                content: Container(
                                                  height: 260,
                                                  child: Column(
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(2.0),
                                                        child: Center(
                                                            child: SizedBox(
                                                          height: 75,
                                                          width: 75,
                                                          child: _image == null
                                                              ? const Center(
                                                                  child: Text(
                                                                      'No Image selected'))
                                                              : Image.file(
                                                                  _image!,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                ),
                                                        )),
                                                      ),
                                                      ElevatedButton(
                                                          onPressed: () async {
                                                            var pickedFile =
                                                                await _picker.pickImage(
                                                                    source: ImageSource
                                                                        .gallery);
                                                            if (pickedFile !=
                                                                null) {
                                                              setState(() {
                                                                _image = File(
                                                                    pickedFile
                                                                        .path);
                                                              });
                                                            }
                                                          },
                                                          child: Text(
                                                              "Pick image")),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(5),
                                                        child: TextField(
                                                          controller:
                                                              _controller,
                                                          decoration:
                                                              InputDecoration(
                                                            border:
                                                                OutlineInputBorder(),
                                                            labelText:
                                                                "Name of expense",
                                                          ),
                                                          onChanged: (value) {
                                                            name = value;
                                                          },
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.all(5),
                                                        child: TextField(
                                                          controller:
                                                              _controller2,
                                                          decoration:
                                                              InputDecoration(
                                                            border:
                                                                OutlineInputBorder(),
                                                            labelText:
                                                                "Cost of expense",
                                                          ),
                                                          onChanged: (value) {
                                                            cost = double.parse(
                                                                value);
                                                          },
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  Padding(
                                                    padding: EdgeInsets.all(25),
                                                    child: ElevatedButton(
                                                        onPressed: () async {
                                                          updateExpense(
                                                              Expense(
                                                                  name: name,
                                                                  cost: cost,
                                                                  image: base64Encode(_image !=
                                                                          null
                                                                      ? await _image!
                                                                          .readAsBytes()
                                                                      : (await rootBundle.load(
                                                                              'assets/no-image-icon.png'))
                                                                          .buffer
                                                                          .asUint8List()),
                                                                  date: DateTime
                                                                          .now()
                                                                      .toString()
                                                                      .substring(
                                                                          0,
                                                                          19)),
                                                              _list[index]
                                                                  .name);

                                                          _list =
                                                              await retrieveExpenses();

                                                          _listCopy = _list;
                                                          balance -= cost;
                                                          setState(() {
                                                            updateBalance();
                                                            cost = 0;
                                                            name = "";
                                                          });
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                        child: Text("Save")),
                                                  ),
                                                ],
                                              ));
                                    } else if (item == Item.delete) {
                                      deleteExpense(_list[index].name);
                                    }
                                  });

                                  _list = await retrieveExpenses();

                                  setState(() {});
                                },
                                itemBuilder: (BuildContext context) {
                                  return <PopupMenuEntry<Item>>[
                                    const PopupMenuItem<Item>(
                                        child: Text("Edit"), value: Item.edit),
                                    const PopupMenuItem<Item>(
                                        child: Text("Delete"),
                                        value: Item.delete)
                                  ];
                                },
                              ),
                              leading: Image.memory(
                                base64Decode(_list[index].image),
                                fit: BoxFit.cover,
                                width: 100,
                                height: 250,
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
                                                                              double.parse(value);
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
                                                                        prefs.setDouble(
                                                                            'balance',
                                                                            double.parse(balance.toStringAsFixed(2)));
                                                                        cost =
                                                                            0;
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
                                                                                double.parse(value);
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
                                                                              image: base64Encode(_image != null ? await _image!.readAsBytes() : (await rootBundle.load('assets/no-image-icon.png')).buffer.asUint8List()),
                                                                              date: DateTime.now().toString().substring(0, 19)));

                                                                          _list =
                                                                              await retrieveExpenses();

                                                                          _listCopy =
                                                                              _list;
                                                                          balance -=
                                                                              cost;
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
