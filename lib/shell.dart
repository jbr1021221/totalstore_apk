import 'package:flutter/material.dart';
import 'screens/catalog.dart';
import 'screens/home.dart';
import 'screens/more.dart';
import 'screens/chat.dart';
import 'screens/orders.dart';
import 'theme.dart';

/// Lets other tabs ask the Orders tab to open on a given filter (index into OrdersScreen.filters).
final ordersFilter = ValueNotifier<int?>(null);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onNavigate: go),
      const OrdersScreen(),
      const CatalogScreen(),
      const MessagesScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              _item(0, Icons.home_outlined, Icons.home, 'Home'),
              _item(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
              _item(2, Icons.inventory_2_outlined, Icons.inventory_2, 'Catalog'),
              _item(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'Messages'),
              _item(4, Icons.more_horiz, Icons.more_horiz, 'More'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData off, IconData on, String label, {bool badge = false}) {
    final sel = index == i;
    Widget icon = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: sel ? C.primary : Colors.transparent, shape: BoxShape.circle),
      child: Icon(sel ? on : off, size: 19, color: sel ? Colors.white : C.sub),
    );
    if (badge) icon = Badge(smallSize: 8, backgroundColor: C.red, child: icon);
    return Expanded(
      child: InkWell(
        onTap: () => go(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          Text(label, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? C.text : C.sub)),
        ]),
      ),
    );
  }
}
