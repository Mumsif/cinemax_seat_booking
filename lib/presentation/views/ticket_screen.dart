import 'package:flutter/material.dart';

class TicketScreen extends StatefulWidget {
  final List<String>? selectedSeats;
    final String movieName;
    final String cinemaName;
    final String showTime;
    final String movieImageUrl;
    final DateTime selectedDate;
    final String rating;

  const TicketScreen({super.key, this.selectedSeats, required this.movieName, required this.cinemaName, required this.showTime, required this.movieImageUrl, required this.selectedDate, required this.rating});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  @override
  Widget build(BuildContext context) {
    final double sp = MediaQuery.of(context).size.width / 375;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Your Ticket', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          width:270,
          height:500,
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/movies/ticket_image.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children:[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.movieImageUrl,
                      width: 85 * sp,
                      height:120 * sp,
                      fit: BoxFit.cover,
                    )
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text(
                          widget.movieName, 
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.yellow, size: 15),
                            const SizedBox(width: 5),
                            Text(widget.rating, style: TextStyle(fontSize: 14, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 35),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height:10),
                    Text(widget.cinemaName, style: TextStyle(fontSize: 18, color: Colors.white,fontWeight: FontWeight.bold),),
                    const SizedBox(height: 4),
                    Container(height: 1, color: Colors.grey),
                    const SizedBox(height:10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Date: ", style: TextStyle(fontSize: 14, color: Colors.white),),
                        Text("${widget.selectedDate}".substring(0, 10), style: TextStyle(fontSize: 14, color: Colors.white),),
                      ],
                    ),
                    const SizedBox(height:10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Time: ", style: TextStyle(fontSize: 14, color: Colors.white),),
                        Text(widget.showTime, style: TextStyle(fontSize: 14, color: Colors.white),),
                      ],
                    ),
                    const SizedBox(height:10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Seats: ", style: TextStyle(fontSize: 14, color: Colors.white),),
                        Flexible(
                          child: Text(
                            "${widget.selectedSeats?.join(', ')}",
                            style: TextStyle(fontSize: 14, color: Colors.white),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
