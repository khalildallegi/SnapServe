// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors, prefer_final_fields, prefer_const_literals_to_create_immutables, use_build_context_synchronously, sort_child_properties_last, unused_element, unnecessary_null_comparison, avoid_print, unnecessary_string_interpolations, prefer_const_declarations

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:http/http.dart' as http;

Future<void> checkPermissions() async {
  try {
    PermissionStatus status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (status != PermissionStatus.granted) {
        print('Storage permission not granted');
      }
    }
  } catch (e) {
    print('Error checking permissions: $e');
  }
}

class OrdersHelper {
  static final String ordersTable = 'orders';
  static final String orderItemsTable = 'order_items';

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // Check if table_number column exists before adding it
      var table = await db.rawQuery('PRAGMA table_info($ordersTable)');
      var hasTableNumberColumn =
          table.any((column) => column['name'] == 'table_number');

      if (!hasTableNumberColumn) {
        print('Adding table_number column');
        await db.execute(
          'ALTER TABLE $ordersTable ADD COLUMN table_number INTEGER',
        );
      } else {
        print('table_number column already exists');
      }
    }
  }

  Future<Database> get database async {
    return openDatabase(
      join(await getDatabasesPath(), 'orders_database.db'),
      version: 2, // Adjust version number as needed
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Creating tables');
    await db.execute(
      'CREATE TABLE $ordersTable('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'total_price REAL, '
      'table_number INTEGER)',
    );
    await db.execute(
      'CREATE TABLE $orderItemsTable('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'order_id INTEGER, '
      'name TEXT, '
      'quantity INTEGER, '
      'total_price REAL, '
      'FOREIGN KEY(order_id) REFERENCES $ordersTable(id) ON DELETE CASCADE)',
    );
  }

  Future<int> insertOrder(double totalPrice, int tableNumber) async {
    final db = await database;
    return await db.insert(ordersTable, {
      'total_price': totalPrice,
      'table_number': tableNumber,
    });
  }

  Future<void> insertOrderItem(int orderId, Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(orderItemsTable, {
      'order_id': orderId,
      'name': item['name'],
      'quantity': item['quantity'],
      'total_price': item['total_price'],
    });
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await database;
    return await db.query(ordersTable);
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final db = await database;
    return await db
        .query(orderItemsTable, where: 'order_id = ?', whereArgs: [orderId]);
  }

  Future<void> deleteOrder(int id) async {
    final db = await database;
    await db.delete(ordersTable, where: 'id = ?', whereArgs: [id]);
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  static const String tableName = 'menu_items';
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnDescription = 'description';
  static const String columnSection = 'section';
  static const String columnPrice = 'price';
  static const String columnImage = 'image';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await initializeDatabase();
    return _database!;
  }

  Future<Database> initializeDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'menu_database.db');

    // Open/create the database at a specific path
    return await openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $tableName('
          '$columnId INTEGER PRIMARY KEY AUTOINCREMENT, '
          '$columnName TEXT, '
          '$columnDescription TEXT, '
          '$columnSection TEXT, '
          '$columnPrice REAL, '
          '$columnImage TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<int> getItemCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
    int count = Sqflite.firstIntValue(result) ?? 0;
    return count;
  }

  Future<int> insertMenuItem(MenuItemModel item) async {
    final db = await database;
    return await db.insert(
      tableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MenuItemModel>> getMenuItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return List.generate(maps.length, (i) {
      return MenuItemModel.fromMap(maps[i]);
    });
  }

  Future<int> updateMenuItem(MenuItemModel item) async {
    final db = await database;
    return await db.update(
      tableName,
      item.toMap(),
      where: '$columnId = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteMenuItem(int id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await checkPermissions(); // Ensuring permissions are checked

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KSI SnapServe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              height: 500,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor,
                  ],
                  stops: const [0, 0.5, 1],
                  begin: AlignmentDirectional(-1, -1),
                  end: AlignmentDirectional(1, 1),
                ),
              ),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _animation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0x00FFFFFF),
                        Theme.of(context).primaryColor,
                      ],
                      stops: const [0, 1],
                      begin: const AlignmentDirectional(0, -1),
                      end: const AlignmentDirectional(0, 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/logoksi.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 44),
                        child: Text(
                          'KSI SnapServe',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(44, 8, 44, 0),
                        child: Center(
                          child: Text(
                            'SnapServe: Simplifying Orders for Waiters',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 44),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.center,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to login page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginPage(),
                            ),
                          );
                        },
                        child: const Text('Enter your pin code'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(230, 52),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _enteredPin = '';

  void _addDigit(String digit) {
    setState(() {
      _enteredPin += digit;
    });
  }

  void _removeDigit() {
    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  void _submitPin(BuildContext context) {
    print('Entered PIN: $_enteredPin');
    if (_enteredPin == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Invalid PIN'),
            content: Text('Please try again.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildPinButton(String digit) {
    return ElevatedButton(
      onPressed: () {
        _addDigit(digit);
      },
      child: Text(
        digit,
        style: TextStyle(fontSize: 20.0),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: EdgeInsets.all(20.0),
        shape: CircleBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: Container(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logoksi.png',
              width: 150,
              height: 150,
            ),
            SizedBox(height: 20.0),
            Text(
              'Enter your PIN',
              style: TextStyle(fontSize: 20.0),
            ),
            SizedBox(height: 20.0),
            Text(
              _enteredPin,
              style: TextStyle(fontSize: 30.0),
            ),
            SizedBox(height: 20.0),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPinButton('1'),
                    _buildPinButton('2'),
                    _buildPinButton('3'),
                  ],
                ),
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPinButton('4'),
                    _buildPinButton('5'),
                    _buildPinButton('6'),
                  ],
                ),
                SizedBox(height: 10.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _removeDigit,
                      child: Icon(Icons.backspace),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.all(20.0),
                        shape: CircleBorder(),
                      ),
                    ),
                    _buildPinButton('0'),
                    ElevatedButton(
                      onPressed: () {
                        _submitPin(context);
                      },
                      child: Icon(Icons.check),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.all(20.0),
                        shape: CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    MenuPage(),
    OrdersPage(),
    Tables1Widget(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            // Additional SliverAppBar configuration can be added here
          ),
        ],
        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.blue, // Background color of the navigation bar
        color: Colors.white, // Color of the button background when selected
        buttonBackgroundColor: Colors.white, // Background color of the button
        height: 50, // Height of the navigation bar
        items: <Widget>[
          Icon(Icons.restaurant_menu,
              size: 30, color: Colors.blue), // Menu icon
          Icon(Icons.shopping_cart,
              size: 30, color: Colors.blue), // Orders icon
          Icon(Icons.table_chart, size: 30, color: Colors.blue), // Tables icon
          Icon(Icons.settings, size: 30, color: Colors.blue), // Settings icon
        ],
        index: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Additional logic can be added here for onTap
        },
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  Map<int, List<Map<String, dynamic>>> _orderItems = {};
  final OrdersHelper _ordersHelper = OrdersHelper();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await _ordersHelper.getOrders();
    final orderItems = <int, List<Map<String, dynamic>>>{};

    for (var order in orders) {
      final items = await _ordersHelper.getOrderItems(order['id']);
      orderItems[order['id']] = items;
    }

    setState(() {
      _orders = orders;
      _orderItems = orderItems;
    });
  }

  void _deleteOrder(int id) async {
    await _ordersHelper.deleteOrder(id);
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text('Stored Orders'),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _orders.isEmpty
          ? Center(child: Text('No orders found'))
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final items = _orderItems[order['id']] ?? [];
                double totalPrice = order['total_price'];

                return ExpansionTile(
                  title: Text(
                      'Order Number ${order['id']} - Total: \$${totalPrice.toStringAsFixed(2)}'),
                  children: [
                    for (var item in items)
                      ListTile(
                        title: Text(item['name']),
                        subtitle: Text(
                            'Quantity: ${item['quantity']}, Total: \$${item['total_price']}'),
                      ),
                    ListTile(
                      title: Text(
                          'Total Price: \$${totalPrice.toStringAsFixed(2)}'),
                    ),
                    ListTile(
                      trailing: IconButton(
                        icon: Icon(Icons.check_box),
                        onPressed: () => _deleteOrder(order['id']),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class MenuPage extends StatefulWidget {
  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedSegment = 'Restaurant';
  List<MenuItemModel> _items = [];
  Set<MenuItemModel> _selectedItems = {};
  GlobalKey<_MenuPageState> _menuPageKey = GlobalKey<_MenuPageState>();
  final TextEditingController _tableNumberController = TextEditingController();
  int _itemCount = 0;
  List<String> orders = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  Future<void> _updateItemCount() async {
    setState(() async {
      _itemCount = await DatabaseHelper().getItemCount();
    });
  }

  Future<void> _loadMenuItems() async {
    try {
      final items = await DatabaseHelper().getMenuItems();
      setState(() {
        _items = items;
      });
    } catch (error) {
      final BuildContext? context = _menuPageKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load menu items')),
        );
      } else {
        print('Error: _menuPageKey.currentContext is null');
      }
    }
  }

  void _onSegmentSelected(String segment) {
    setState(() {
      _selectedSegment = segment;
    });
  }

  void _onItemSelected(MenuItemModel item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        item.quantity++;
      } else {
        item.quantity = 1;
        _selectedItems.add(item);
      }
    });
  }

  void _onItemUnselected(MenuItemModel item) {
    setState(() {
      _selectedItems.remove(item);
    });
  }

  void _placeOrder(BuildContext context) async {
    try {
      await _saveOrderToDatabase(); // Save order to database first

      // Convert order to JSON
      String jsonOrder = _createJsonOrder();

      // Add current order to orders list
      orders.add(jsonOrder);

      // Send the last order dynamically
      await _sendLastOrder();

      setState(() {
        _selectedItems.clear(); // Clear selected items after order is saved
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order placed successfully'),
          duration: Duration(seconds: 2),
        ),
      );

      // After sending the last order, clear all orders
      orders.clear(); // Clear all orders
    } catch (e) {
      print('Error placing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order. Please try again later.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _createJsonOrder() {
    // Create a map representing the order
    Map<String, dynamic> order = {
      'tableNumber': int.parse(_tableNumberController.text),
      'items': _selectedItems.map((item) {
        return {
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'totalPrice': item.price * item.quantity,
        };
      }).toList(),
    };

    // Convert map to JSON string
    String jsonOrder = json.encode(order);
    return jsonOrder;
  }

  Future<void> _sendLastOrder() async {
    if (orders.isEmpty) {
      print('No orders to send.');
      return;
    }

    // Get the last order from the list
    String lastOrder = orders.last;

    final url = Uri.parse(
        'https://85.31.239.171/neworder.php'); // Replace with your API endpoint
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: lastOrder,
    );

    if (response.statusCode == 200) {
      print('Last order sent successfully');
      // Do not remove the last order from the list, as we clear all orders in _placeOrder()
    } else {
      throw Exception(
          'Failed to send order. Status code: ${response.statusCode}');
    }
  }

  void _showOrderPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Customer(s) Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input field for table number
                TextField(
                  controller: _tableNumberController,
                  decoration: InputDecoration(labelText: 'Table Number'),
                  keyboardType: TextInputType.number,
                ),
                // List of selected items displayed as ListTile
                ..._selectedItems.map((item) {
                  return ListTile(
                    title: Text('${item.name}'),
                    subtitle: Row(
                      children: [
                        // IconButton to decrease item quantity
                        IconButton(
                          icon: Icon(Icons.remove),
                          color: Colors.red,
                          onPressed: () {
                            setState(() {
                              if (item.quantity > 1) {
                                item.quantity--;
                              } else {
                                _selectedItems.remove(item);
                              }
                            });
                          },
                        ),
                        // Display item quantity dynamically
                        Text(
                          '${item.quantity}',
                          key: Key(
                              'itemQuantity'), // Add a key to uniquely identify this widget
                        ),
                        // IconButton to increase item quantity
                        IconButton(
                          icon: Icon(Icons.add),
                          color: Colors.green,
                          onPressed: () {
                            setState(() {
                              item.quantity++;
                            });
                          },
                        ),
                      ],
                    ),
                    trailing: Text(
                      '\$${(item.price * item.quantity).toStringAsFixed(2)}', // Calculate total price for the item
                    ),
                  );
                }).toList(), // Convert selected items to List<Widget>
              ],
            ),
          ),
          actions: <Widget>[
            // Button to exit the dialog
            TextButton(
              child: Text('Exit'),
              onPressed: () {
                setState(() {
                  _selectedItems.clear(); // Clear all selected items
                });
                Navigator.of(dialogContext)
                    .pop(); // Close the dialog using dialogContext
              },
            ),
            // Button to place the order
            TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.disabled)) {
                      return Colors
                          .grey; // Adjust color for disabled state if needed
                    }
                    return Colors.blue; // Default color for enabled state
                  },
                ),
                textStyle: WidgetStateProperty.resolveWith<TextStyle>(
                  (Set<WidgetState> states) {
                    return TextStyle(
                      fontSize: 16, // Adjust font size as needed
                    );
                  },
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _placeOrder(context);
              },
              child: Text('Order'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveOrderToDatabase() async {
    final ordersHelper = OrdersHelper();
    double totalPrice = 0;
    for (var item in _selectedItems) {
      totalPrice += item.price * item.quantity;
    }
    print('Inserting order with total price: $totalPrice');
    int orderId = await ordersHelper.insertOrder(
        totalPrice, int.parse(_tableNumberController.text));
    print('Order ID: $orderId');
    for (var item in _selectedItems) {
      print('Inserting item: ${item.name}');
      await ordersHelper.insertOrderItem(orderId, {
        'name': item.name,
        'quantity': item.quantity,
        'total_price': item.price * item.quantity,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _menuPageKey,
      appBar: AppBar(
        title: Text('Menu'),
        
        automaticallyImplyLeading: false,
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final filteredItems =
              _items.where((item) => item.section == _selectedSegment).toList();

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _onSegmentSelected('Restaurant'),
                      child: Text('Restaurant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedSegment == 'Restaurant'
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _onSegmentSelected('Bar'),
                      child: Text('Bar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedSegment == 'Bar'
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: _items.isEmpty
                      ? Center(child: CircularProgressIndicator())
                      : orientation == Orientation.portrait
                          ? _buildPortraitLayout(filteredItems)
                          : _buildLandscapeLayout(filteredItems),
                ),
                if (_selectedItems.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => _showOrderPopup(context),
                    child: Text('Review Order (${_selectedItems.length})'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitLayout(List<MenuItemModel> filteredItems) {
    return GridView.builder(
      itemCount: filteredItems.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (BuildContext context, int index) {
        final item = filteredItems[index];
        return Card(
          elevation: 5,
          margin: EdgeInsets.all(10),
          child: SizedBox(
            width: 100, // Set desired width of each card
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                item.image != null
                    ? Image.file(
                        File(item.image),
                        width: 50,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons
                              .image); // Placeholder icon for invalid images
                        },
                      )
                    : Icon(Icons.image,
                        size: 50), // Placeholder icon for null image paths
                SizedBox(height: 5), // Space between image and text
                Text(item.name, textAlign: TextAlign.center), // Center text
                GestureDetector(
                  onTap: () => _onItemSelected(item),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shopping_cart),
                      if (item.quantity > 1)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              item.quantity.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandscapeLayout(List<MenuItemModel> filteredItems) {
    return GridView.builder(
      itemCount: filteredItems.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (BuildContext context, int index) {
        final item = filteredItems[index];
        return Card(
          elevation: 5,
          margin: EdgeInsets.all(5),
          child: SizedBox(
            width: 80, // Set desired width of each card
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                item.image != null
                    ? Image.file(
                        File(item.image),
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons
                              .image); // Placeholder icon for invalid images
                        },
                      )
                    : Icon(Icons.image,
                        size: 40), // Placeholder icon for null image paths
                SizedBox(height: 5), // Space between image and text
                Text(item.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12)), // Center text with smaller font
                GestureDetector(
                  onTap: () => _onItemSelected(item),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.shopping_cart, size: 20), // Smaller icon
                      if (item.quantity > 1)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: Text(
                              item.quantity.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SegmentedButton extends StatelessWidget {
  final List<ButtonSegment> segments;
  final String selected;

  const SegmentedButton({
    Key? key,
    required this.segments,
    required this.selected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      borderRadius: BorderRadius.circular(20), // Add rounded corners
      children: segments
          .map<Widget>(
            (segment) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(segment.icon),
                  SizedBox(width: 8),
                  segment.label,
                ],
              ),
            ),
          )
          .toList(),
      isSelected: segments.map((e) => e.label.toString() == selected).toList(),
      onPressed: (index) {
        segments[index].onTap();
      },
    );
  }
}

class ButtonSegment {
  final IconData icon;
  final Widget label;
  final VoidCallback onTap;

  const ButtonSegment({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class MenuItemModel {
  final int? id;
  final String name;
  final String description;
  final String section;
  final double price;
  final String image;
  int quantity;

  MenuItemModel({
    this.id,
    required this.name,
    required this.description,
    required this.section,
    required this.price,
    required this.image,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'section': section,
      'price': price,
      'image': image,
    };
  }

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      section: map['section'],
      price: map['price'],
      image: map['image'],
    );
  }

  static List<MenuItemModel> items = []; // Define items list here

  static void clearItems() {
    items.clear();
  }

  static void addItem(MenuItemModel item) {
    items.add(item);
  }

  static void removeItem(int index) {
    items.removeAt(index);
  }

  static void updateItem(int index, MenuItemModel updatedItem) {
    items[index] = updatedItem;
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedSection = 'Restaurant';
  String? _image;
  final ImagePicker _picker = ImagePicker();
  MenuItemModel? _editingItem;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      setState(() {
        _image = pickedFile?.path;
      });
    } catch (e) {
      // Handle errors if any
    }
  }

  Future<void> _fetchItems() async {
    try {
      List<MenuItemModel> items = await DatabaseHelper().getMenuItems();
      setState(() {
        MenuItemModel.items = items;
      });
    } catch (e) {
      // Handle errors if any
    }
  }

  void _addItem() {
    if (_formKey.currentState!.validate()) {
      final newItem = MenuItemModel(
        name: _nameController.text,
        description: _descriptionController.text,
        section: _selectedSection,
        price: double.parse(_priceController.text),
        image: _image!,
      );
      DatabaseHelper().insertMenuItem(newItem).then((_) {
        setState(() {
          _nameController.clear();
          _descriptionController.clear();
          _priceController.clear();
          _image = null;
          _fetchItems();
        });
      });
    }
  }

  void _updateItem() {
    if (_formKey.currentState!.validate() && _editingItem != null) {
      final updatedItem = MenuItemModel(
        id: _editingItem!.id,
        name: _nameController.text,
        description: _descriptionController.text,
        section: _selectedSection,
        price: double.parse(_priceController.text),
        image: _image!,
      );
      DatabaseHelper().updateMenuItem(updatedItem).then((_) {
        setState(() {
          _editingItem = null;
          _nameController.clear();
          _descriptionController.clear();
          _priceController.clear();
          _image = null;
          _fetchItems();
        });
      });
    }
  }

  void _removeItem(int index) {
    if (MenuItemModel.items[index].id != null) {
      DatabaseHelper().deleteMenuItem(MenuItemModel.items[index].id!).then((_) {
        setState(() {
          MenuItemModel.items.removeAt(index);
        });
      });
    }
  }

  void _startEditing(int index) {
    setState(() {
      _editingItem = MenuItemModel.items[index];
      _nameController.text = _editingItem!.name;
      _descriptionController.text = _editingItem!.description;
      _priceController.text = _editingItem!.price.toString();
      _selectedSection = _editingItem!.section;
      _image = _editingItem!.image;
    });
  }

  List<MenuItemModel> _filterItemsBySection(String section) {
    return MenuItemModel.items
        .where((item) => item.section == section)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(labelText: 'Price'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedSection,
              items: ['Restaurant', 'Bar']
                  .map((section) => DropdownMenuItem(
                        child: Text(section),
                        value: section,
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSection = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Section'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _getImage(ImageSource.camera),
                  child: Text('Camera'),
                ),
                ElevatedButton(
                  onPressed: () => _getImage(ImageSource.gallery),
                  child: Text('Gallery'),
                ),
              ],
            ),
            if (_image != null)
              Image.file(
                File(_image!),
                width: 100,
                height: 100,
              ),
            ElevatedButton(
              onPressed: _editingItem == null ? _addItem : _updateItem,
              child: Text(_editingItem == null ? 'Add Item' : 'Update Item'),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildSectionList('Restaurant'),
                  _buildSectionList('Bar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionList(String section) {
    final items = _filterItemsBySection(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            section,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(items[index].name),
              subtitle: Text(items[index].description),
              trailing: Wrap(
                spacing: 12,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      _startEditing(MenuItemModel.items.indexOf(items[index]));
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () =>
                        _removeItem(MenuItemModel.items.indexOf(items[index])),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class Tables1Widget extends StatefulWidget {
  const Tables1Widget({Key? key}) : super(key: key);

  @override
  State<Tables1Widget> createState() => _Tables1WidgetState();
}

class _Tables1WidgetState extends State<Tables1Widget> {
  List<Map<String, dynamic>> _orders = [];
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final OrdersHelper _ordersHelper = OrdersHelper();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _ordersHelper.getOrders();
      setState(() {
        _orders = orders.map((order) {
          // Ensure table_number is treated as an integer
          return {
            ...order,
            'table_number': order['table_number'] is String
                ? int.parse(order['table_number'])
                : order['table_number'],
          };
        }).toList();
      });
    } catch (e) {
      _showSnackBar('Error loading orders: $e');
    }
  }

  Future<void> _deleteOrder(int id) async {
    try {
      await _ordersHelper.deleteOrder(id);
      _loadOrders(); // Reload orders after deletion
    } catch (e) {
      _showSnackBar('Error deleting order: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(scaffoldKey.currentContext!).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Map<int, List<Map<String, dynamic>>> _groupOrdersByTableNumber() {
    Map<int, List<Map<String, dynamic>>> groupedOrders = {};
    for (var order in _orders) {
      int tableNumber = order['table_number'];
      if (!groupedOrders.containsKey(tableNumber)) {
        groupedOrders[tableNumber] = [];
      }
      groupedOrders[tableNumber]!.add(order);
    }
    return groupedOrders;
  }

  double _calculateTotalPrice(List<Map<String, dynamic>> orders) {
    double totalPrice = 0.0;
    for (var order in orders) {
      totalPrice += order['total_price'];
    }
    return totalPrice;
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = _groupOrdersByTableNumber();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        'Tables',
                        style: TextStyle(
                            fontSize: 24.0, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: groupedOrders.keys.length,
                    itemBuilder: (context, index) {
                      int tableNumber = groupedOrders.keys.elementAt(index);
                      List<Map<String, dynamic>> orders =
                          groupedOrders[tableNumber]!;
                      double totalPrice = _calculateTotalPrice(orders);

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Table $tableNumber',
                                  style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold),
                                ),
                                Spacer(),
                                Text(
                                  'Total: \$${totalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            ...orders.map((order) {
                              return FutureBuilder<List<Map<String, dynamic>>>(
                                future:
                                    _ordersHelper.getOrderItems(order['id']),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: CircularProgressIndicator());
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else {
                                    final orderItems = snapshot.data ?? [];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Order Number: ${order['id']}',
                                              style: TextStyle(fontSize: 16.0),
                                            ),
                                            Spacer(),
                                            IconButton(
                                              icon: Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _deleteOrder(order['id']),
                                            ),
                                          ],
                                        ),
                                        ...orderItems.map((item) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              '${item['name']} - ${item['quantity']} x \$${item['total_price']}',
                                              style: TextStyle(fontSize: 14.0),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
