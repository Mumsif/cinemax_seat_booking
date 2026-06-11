import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/presentation/views/seat_selection_screen.dart';

class ShowtimeSelection extends StatefulWidget {
  final String movieName;
  final String cinemaName;
  final String movieImageUrl;
  final String rating;
  final String? preselectedTime;
  final List<String>? availableShowTimes; // If provided, only show these slots for the movie/cinema

  const ShowtimeSelection({
    super.key,
    required this.movieName,
    required this.cinemaName,
    required this.movieImageUrl,
    required this.rating,
    this.preselectedTime,
    this.availableShowTimes,
  });

  @override
  State<ShowtimeSelection> createState() => _ShowtimeSelectionState();
}

class _ShowtimeSelectionState extends State<ShowtimeSelection> {
  int _selectedDateIndex = 0;
  int _selectedTimeIndex = -1;

  final List<String> _defaultTimes = [
    '06:00 AM',
    '10:30 AM',
    '02:30 PM',
    '06:30 PM',
    '10:30 PM',
  ];

  late List<String> _displayTimes;

  @override
  void initState() {
    super.initState();
    _displayTimes = (widget.availableShowTimes != null && widget.availableShowTimes!.isNotEmpty)
        ? widget.availableShowTimes!
        : _defaultTimes;

    if (widget.preselectedTime != null) {
      final index = _displayTimes.indexOf(widget.preselectedTime!);
      if (index != -1) {
        _selectedTimeIndex = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Date',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 62,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = _selectedDateIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDateIndex = index;
                        // Don't reset time if preselected
                        if (widget.preselectedTime == null) {
                          _selectedTimeIndex = -1;
                        }
                      });
                    },
                    child: Container(
                      width: 48,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE50914)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ][date.weekday - 1],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2C2C2C)),
            const SizedBox(height: 30),
            Row(
              children: [
                const Text(
                  'Select Showtime',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.preselectedTime != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFE50914).withOpacity(0.5),
                      ),
                    ),
                    child: const Text(
                      'Pre-selected',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: _displayTimes.length,
              itemBuilder: (context, index) {
                return _timeSlot(_displayTimes[index], index);
              },
            ),
            const SizedBox(height: 350),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _selectedTimeIndex == -1
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeatSelectionScreen(
                              movieName: widget.movieName,
                              cinemaName: widget.cinemaName,
                              movieImageUrl: widget.movieImageUrl,
                              showTime: _displayTimes[_selectedTimeIndex],
                              selectedDate: DateTime.now().add(
                                Duration(days: _selectedDateIndex),
                              ),
                              rating: widget.rating,
                            ),
                          ),
                        );
                      },
                child: const Text(
                  'Select Seat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _timeSlot(String time, int index) {
    final isSelected = _selectedTimeIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeIndex = index;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE50914) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE50914)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          time,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}