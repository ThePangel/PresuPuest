import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/services.dart' show rootBundle;

List<Expense> _listExpense = [];
List<Expense> _listExpenseCopy = [];
List<Balance> _listBalance = [];
List<Balance> _listBalanceCopy = [];
var database;
double balance = 0;

enum Item { edit, delete }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  database = openDatabase(
    join(await getDatabasesPath(), 'expenses.db'),
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE expenses(name TEXT PRIMARY KEY, cost REAL, image TEXT, date TEXT)',
      );
      await db.execute(
        'CREATE TABLE balances(name TEXT PRIMARY KEY, cost REAL, date TEXT)',
      );
    },
    version: 1,
  );

  _listExpense = await retrieveExpenses();
  _listExpenseCopy = _listExpense;
  _listBalance = await retrieveBalances();
  _listBalanceCopy = _listBalance;

  updateBalance();
  runApp(const MyApp());
}

Future<void> insertExpense(var table) async {
  final db = await database;
  if (table is Expense) {
    await db.insert(
      'expenses',
      table.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } else if (table is Balance) {
    await db.insert(
      'balances',
      table.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
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

Future<List<Balance>> retrieveBalances() async {
  final db = await database;

  final List<Map<String, Object?>> balanceMaps = await db.query('balances');

  return [
    for (final {
          'name': name as String,
          'cost': cost as double,
          'date': date as String,
        } in balanceMaps)
      Balance(name: name, cost: cost, date: date),
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

Future<void> deleteBalance(String name) async {
  final db = await database;

  await db.delete(
    'balances',
    where: 'name = ?',
    whereArgs: [name],
  );
}

Future<void> updateExpense(var table, String name) async {
  final db = await database;
  if (table is Expense) {
    await db.update(
      'expenses',
      table.toMap(),
      where: 'name = ?',
      whereArgs: [name],
    );
  } else if (table is Balance) {
    await db.update(
      'balances',
      table.toMap(),
      where: 'name = ?',
      whereArgs: [name],
    );
  }
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

Future<Balance> retrieveSingleBalance(String name) async {
  final db = await database;

  final List<Map<String, Object?>> result = await db.query(
    'balances',
    where: 'name = ?',
    whereArgs: [name],
  );

  final Map<String, Object?> expenseMap = result.first;

  return Balance(
    name: expenseMap['name'] as String,
    cost: expenseMap['cost'] as double, // Convert cost to String if needed
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

class Balance {
  final String name;
  final double cost;
  final String date;

  const Balance({
    required this.name,
    required this.cost,
    required this.date,
  });

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'cost': cost,
      'date': date,
    };
  }

  @override
  String toString() {
    return 'Balance{name: $name, cost: $cost, date: $date}';
  }
}

void updateBalance() {
  balance = 0;
  for (int i = 0; i < _listBalance.length; i++) {
    balance += _listBalance[i].cost;
  }
  for (int i = 0; i < _listExpense.length; i++) {
    balance -= _listExpense[i].cost;
  }
}

class _MyAppState extends State<MyApp> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  String name = "";
  double cost = 0;
  TextEditingController editingController = TextEditingController();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();

  void search(String query) {
    setState(() {
      _listExpense = _listExpenseCopy
          .where(
              (item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      _listBalance = _listBalanceCopy
          .where(
              (item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          useMaterial3: true,
          textTheme: GoogleFonts.antonTextTheme(
              Theme.of(context).textTheme.apply(bodyColor: Colors.white)),
          brightness:
              SchedulerBinding.instance.platformDispatcher.platformBrightness),

      //textTheme: ,
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Center(
                child: Text(
                  "PresuPuest",
                  style: TextStyle(color: Colors.white, fontSize: 30),
                ),
              ),
              backgroundColor: Colors.black,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              )),
            ),
            body: Column(
              children: [
                SizedBox(
                  height: 100,
                  child: Stack(children: [
                    Padding(
                        padding: const EdgeInsets.all(5),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text("${balance.toStringAsFixed(2)}€",
                              style: TextStyle(
                                  fontSize: 75,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 4
                                    ..color = Colors.black)),
                        )),
                    Padding(
                        padding: const EdgeInsets.all(5),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text("${balance.toStringAsFixed(2)}€",
                              style: TextStyle(
                                  fontSize: 75,
                                  color: balance < 0
                                      ? Colors.redAccent
                                      : Colors.green)),
                        )),
                  ]),
                ),
                SizedBox(
                    width: 300,
                    child: TextField(
                      controller: editingController,
                      decoration: const InputDecoration(
                          labelText: "Search",
                          hintText: "Search",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(25.0)))),
                      onChanged: (value) => search(value),
                    )),
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text("Expenses",
                      style: TextStyle(
                        fontSize: 25,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )),
                ),
                SizedBox(
                  height: 225,
                  child: Center(
                      child: Card(
                    elevation: 2,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: ListView.builder(
                      itemCount: _listExpense.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                              title: Text(_listExpense[index].name),
                              subtitle: Text(
                                  "${_listExpense[index].cost.toString()} € \n${_listExpense[index].date}"),
                              isThreeLine: true,
                              trailing: PopupMenuButton(
                                onSelected: (Item item) async {
                                  Expense temp = await retrieveSingleExpense(
                                      _listExpense[index].name);
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
                                                title: const Text(
                                                    "Input expenses"),
                                                content: SizedBox(
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
                                                              : Image.memory(
                                                                  base64Decode(
                                                                      _listExpense[
                                                                              index]
                                                                          .image),
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
                                                                        .camera);
                                                            if (pickedFile !=
                                                                null) {
                                                              setState(() {
                                                                _image = File(
                                                                    pickedFile
                                                                        .path);
                                                              });
                                                            }
                                                          },
                                                          child: const Text(
                                                              "Take image")),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        child: TextField(
                                                          controller:
                                                              _controller,
                                                          decoration:
                                                              const InputDecoration(
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
                                                            const EdgeInsets
                                                                .all(5),
                                                        child: TextField(
                                                          controller:
                                                              _controller2,
                                                          decoration:
                                                              const InputDecoration(
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
                                                    padding:
                                                        const EdgeInsets.all(
                                                            25),
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
                                                                  date: _listExpense[
                                                                          index]
                                                                      .date),
                                                              _listExpense[
                                                                      index]
                                                                  .name);

                                                          _listExpense =
                                                              await retrieveExpenses();

                                                          _listExpenseCopy =
                                                              _listExpense;

                                                          setState(() {
                                                            updateBalance();
                                                            _image = null;
                                                            cost = 0;
                                                            name = "";
                                                          });
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                        child:
                                                            const Text("Save")),
                                                  ),
                                                ],
                                              ));
                                    } else if (item == Item.delete) {
                                      deleteExpense(_listExpense[index].name);
                                      
                                    }
                                  });

                                  _listExpense = await retrieveExpenses();

                                  setState(() {updateBalance();});
                                },
                                itemBuilder: (BuildContext context) {
                                  return <PopupMenuEntry<Item>>[
                                    const PopupMenuItem<Item>(
                                      value: Item.edit,
                                      child: Text("Edit"),
                                    ),
                                    const PopupMenuItem<Item>(
                                      value: Item.delete,
                                      child: Text("Delete"),
                                    )
                                  ];
                                },
                              ),
                              leading: Image.memory(
                                base64Decode(_listExpense[index].image),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15.0),
                              )),
                        );
                      },
                    ),
                  )),
                ),
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text("Cash imports",
                      style: TextStyle(
                        fontSize: 25,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )),
                ),
                SizedBox(
                  height: 225,
                  child: Center(
                      child: Card(
                    elevation: 2,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: ListView.builder(
                      itemCount: _listBalance.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                              title: Text(_listBalance[index].name),
                              subtitle: Text(
                                  "${_listBalance[index].cost.toString()} € \n${_listBalance[index].date}"),
                              isThreeLine: true,
                              trailing: PopupMenuButton(
                                onSelected: (Item item) async {
                                  Balance temp = await retrieveSingleBalance(
                                      _listBalance[index].name);
                                  _controller.text = temp.name;
                                  _controller2.text = temp.cost.toString();
                                  name = temp.name;
                                  cost = temp.cost;
                                  setState(() {
                                    if (item == Item.edit) {
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text("Add balance"),
                                              content: SizedBox(
                                                height: 155,
                                                child: Column(
                                                  children: [
                                                    const Text(
                                                        "Input added balance"),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              5),
                                                      child: TextField(
                                                        controller: _controller,
                                                        decoration:
                                                            const InputDecoration(
                                                          border:
                                                              OutlineInputBorder(),
                                                          labelText: "Name",
                                                        ),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            name = value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              5),
                                                      child: TextField(
                                                        controller:
                                                            _controller2,
                                                        decoration:
                                                            const InputDecoration(
                                                          border:
                                                              OutlineInputBorder(),
                                                          labelText:
                                                              "Amount of balance",
                                                        ),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            cost = double.parse(
                                                                value);
                                                          });
                                                        },
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                ElevatedButton(
                                                    onPressed: () async {
                                                      updateExpense(
                                                          Balance(
                                                              name: name,
                                                              cost: cost,
                                                              date:
                                                                  _listBalance[
                                                                          index]
                                                                      .name),
                                                          _listBalance[index]
                                                              .name);
                                                      _listBalance =
                                                          await retrieveBalances();
                                                      _listBalanceCopy =
                                                          _listBalance;

                                                      setState(() {
                                                        updateBalance();
                                                        cost = 0;
                                                      });
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: const Text("Save"))
                                              ],
                                            );
                                          });
                                    } else if (item == Item.delete) {
                                      deleteBalance(_listBalance[index].name);
                                      
                                    }
                                  });

                                  _listBalance = await retrieveBalances();

                                  setState(() {updateBalance();});
                                },
                                itemBuilder: (BuildContext context) {
                                  return <PopupMenuEntry<Item>>[
                                    const PopupMenuItem<Item>(
                                      value: Item.edit,
                                      child: Text("Edit"),
                                    ),
                                    const PopupMenuItem<Item>(
                                      value: Item.delete,
                                      child: Text("Delete"),
                                    )
                                  ];
                                },
                              ),
                              leading: const Icon(Icons.money, size: 60),
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
                    padding: const EdgeInsets.all(20),
                    child: FloatingActionButton(
                        shape: const CircleBorder(),
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
                                                        const Icon(Icons.money),
                                                    onPressed: () {
                                                      showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                              context) {
                                                            return AlertDialog(
                                                              title: const Text(
                                                                  "Add balance"),
                                                              content: SizedBox(
                                                                height: 155,
                                                                child: Column(
                                                                  children: [
                                                                    const Text(
                                                                        "Input added balance"),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .all(
                                                                          5.0),
                                                                      child:
                                                                          TextField(
                                                                        decoration:
                                                                            const InputDecoration(
                                                                          border:
                                                                              OutlineInputBorder(),
                                                                          labelText:
                                                                              "Name",
                                                                        ),
                                                                        onChanged:
                                                                            (value) {
                                                                          setState(
                                                                              () {
                                                                            name =
                                                                                value;
                                                                          });
                                                                        },
                                                                      ),
                                                                    ),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .all(
                                                                          5.0),
                                                                      child:
                                                                          TextField(
                                                                        decoration:
                                                                            const InputDecoration(
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
                                                                            TextInputType.number,
                                                                      ),
                                                                    )
                                                                  ],
                                                                ),
                                                              ),
                                                              actions: [
                                                                ElevatedButton(
                                                                    onPressed:
                                                                        () async {
                                                                      insertExpense(Balance(
                                                                          name:
                                                                              name,
                                                                          cost:
                                                                              cost,
                                                                          date: DateTime.now().toString().substring(
                                                                              0,
                                                                              19)));
                                                                      _listBalance =
                                                                          await retrieveBalances();
                                                                      _listBalanceCopy =
                                                                          _listBalance;

                                                                      setState(
                                                                          () {
                                                                        updateBalance();
                                                                        cost =
                                                                            0;
                                                                      });
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                    },
                                                                    child: const Text(
                                                                        "Save"))
                                                              ],
                                                            );
                                                          });
                                                    }),
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.all(8.0),
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
                                                    child:
                                                        const Icon(Icons.shop),
                                                    onPressed: () {
                                                      showDialog(
                                                          context: context,
                                                          builder: (BuildContext
                                                                  context) =>
                                                              AlertDialog(
                                                                title: const Text(
                                                                    "Input expenses"),
                                                                content:
                                                                    SizedBox(
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
                                                                                await _picker.pickImage(source: ImageSource.camera);
                                                                            if (pickedFile !=
                                                                                null) {
                                                                              setState(() {
                                                                                _image = File(pickedFile.path);
                                                                              });
                                                                            }
                                                                          },
                                                                          child:
                                                                              const Text("Take  image")),
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            5),
                                                                        child:
                                                                            TextField(
                                                                          decoration:
                                                                              const InputDecoration(
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
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            5),
                                                                        child:
                                                                            TextField(
                                                                          decoration:
                                                                              const InputDecoration(
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
                                                                        const EdgeInsets
                                                                            .all(
                                                                            25),
                                                                    child: ElevatedButton(
                                                                        onPressed: () async {
                                                                          insertExpense(Expense(
                                                                              name: name,
                                                                              cost: cost,
                                                                              image: base64Encode(_image != null ? await _image!.readAsBytes() : (await rootBundle.load('assets/no-image-icon.png')).buffer.asUint8List()),
                                                                              date: DateTime.now().toString().substring(0, 19)));

                                                                          _listExpense =
                                                                              await retrieveExpenses();

                                                                          _listExpenseCopy =
                                                                              _listExpense;

                                                                          setState(
                                                                              () {
                                                                            updateBalance();
                                                                            _listExpenseCopy =
                                                                                _listExpense;

                                                                            _image =
                                                                                null;
                                                                            cost =
                                                                                0;
                                                                            name =
                                                                                "";
                                                                          });
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        },
                                                                        child: const Text("Save")),
                                                                  ),
                                                                ],
                                                              ));
                                                    }),
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Text("Add Expense"),
                                              )
                                            ],
                                          ),
                                        ]));
                              });
                        },
                        child: const Icon(Icons.add)),
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
