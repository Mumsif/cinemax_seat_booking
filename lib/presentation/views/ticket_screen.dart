import 'package:flutter/material.dart';

class TicketScreen extends StatefulWidget {
  final List<String>? selectedSeats;

  const TicketScreen({super.key, this.selectedSeats});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Your Ticket', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          width:400,
          height:600,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white,width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            'assets/images/movies/ticket_image.png',
            width:390,
            height:590,
            fit:BoxFit.cover,
            ),
        ),
      ),
    );
  }
}
