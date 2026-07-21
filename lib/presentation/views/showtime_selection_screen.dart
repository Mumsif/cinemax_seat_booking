import 'package:flutter/material.dart';
import 'package:cinemax_seat_booking/presentation/views/seat_selection_screen.dart';

class ShowtimeSelection extends StatefulWidget {
  final String movieName;
  final String cinemaName;
  final String movieImageUrl;
  final String rating;
  final String? preselectedTime;
  final List<String>? availableShowTimes;

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
        // Only pre-select if it is not already in the past for today's date (initial date index is 0)
        final initialDate = DateTime.now().add(Duration(days: _selectedDateIndex));
        if (!isShowtimePast(widget.preselectedTime!, initialDate)) {
          _selectedTimeIndex = index;
        }
        // else: leave as -1 so a past preselected time does not allow booking a past show
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
                  final now = DateTime.now();
                  final date = now.add(Duration(days: index));
                  // Add check for past dates (requirement 6): even though we generate from today forward,
                  // explicitly compute and disable any past dates for robustness (e.g. date rollover, clock changes).
                  final dateOnly = DateTime(date.year, date.month, date.day);
                  final todayOnly = DateTime(now.year, now.month, now.day);
                  final isPastDate = dateOnly.isBefore(todayOnly);
                  final isSelected = _selectedDateIndex == index && !isPastDate;

                  return GestureDetector(
                    onTap: isPastDate
                        ? null
                        : () {
                            setState(() {
                              _selectedDateIndex = index;
                              final newSelDate = DateTime.now().add(Duration(days: index));
                              // Reset time selection on date change, unless it's a valid preselected
                              if (widget.preselectedTime == null) {
                                _selectedTimeIndex = -1;
                              } else {
                                // If preselected time is now past for the newly chosen date, clear it
                                if (isShowtimePast(widget.preselectedTime!, newSelDate)) {
                                  _selectedTimeIndex = -1;
                                }
                              }
                              // If an existing time selection is now invalid (past) for this date, clear it
                              if (_selectedTimeIndex != -1 &&
                                  _selectedTimeIndex < _displayTimes.length) {
                                final selTime = _displayTimes[_selectedTimeIndex];
                                if (isShowtimePast(selTime, newSelDate)) {
                                  _selectedTimeIndex = -1;
                                }
                              }
                            });
                          },
                    child: Container(
                      width: 48,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isPastDate
                            ? const Color(0xFF2A2A2A)
                            : (isSelected ? const Color(0xFFE50914) : const Color(0xFF1E1E1E)),
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
                              color: isPastDate
                                  ? Colors.grey[600]
                                  : (isSelected ? Colors.white : Colors.grey),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isPastDate ? Colors.grey[600] : Colors.white,
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
                final time = _displayTimes[index];
                // Compute the currently chosen date for this showtime check.
                // The date list always uses DateTime.now().add(days: _selectedDateIndex)
                final selectedDate = DateTime.now().add(Duration(days: _selectedDateIndex));
                final isPast = isShowtimePast(time, selectedDate);
                // Pass disabled state to _timeSlot so it can grey out and make non-clickable
                return _timeSlot(time, index, isDisabled: isPast);
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
                onPressed: (_selectedTimeIndex == -1 || _selectedTimeIndex >= _displayTimes.length)
                    ? null
                    : () {
                        // Double-check at tap time that the chosen showtime is not past for the selected date.
                        // This guards against time passing while the screen is open, or preselected invalid times.
                        final selDate = DateTime.now().add(Duration(days: _selectedDateIndex));
                        final chosenTime = _displayTimes[_selectedTimeIndex];
                        if (isShowtimePast(chosenTime, selDate)) {
                          // Invalid now; force clear and do nothing (UI will reflect on next rebuild)
                          setState(() {
                            _selectedTimeIndex = -1;
                          });
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeatSelectionScreen(
                              movieName: widget.movieName,
                              cinemaName: widget.cinemaName,
                              movieImageUrl: widget.movieImageUrl,
                              showTime: chosenTime,
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

  Widget _timeSlot(String time, int index, {bool isDisabled = false}) {
    // isDisabled comes from isShowtimePast(...) in the grid builder.
    // When disabled: onTap is null (non-clickable), background and text greyed out.
    // We also avoid treating it as "selected" visually even if index matches (e.g. stale preselect or time rollover).
    final isSelected = _selectedTimeIndex == index && !isDisabled;

    return GestureDetector(
      // onTap null makes the GestureDetector inert (no ripple/selection)
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedTimeIndex = index;
              });
            },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDisabled
              ? const Color(0xFF2A2A2A) // greyed-out background for past showtimes
              : (isSelected ? const Color(0xFFE50914) : const Color(0xFF1E1E1E)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.15)
                : (isSelected
                    ? const Color(0xFFE50914)
                    : Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: isDisabled ? Colors.grey[600] : Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// Helper function required by the task:
  /// bool isShowtimePast(String showtime, DateTime selectedDate)
  ///
  /// Determines whether the given showtime string (e.g. "6:00 AM", "06:00 AM", "2:30 PM", "10:30 PM")
  /// has already passed for the provided selectedDate, using DateTime.now() for "current time".
  ///
  /// Requirements implemented:
  /// 1. Check if selectedDate is "today" using same year/month/day (ignoring time-of-day component).
  /// 2/3. If today, parse showtime to hour/min and compare its full DateTime against now.
  ///    Disable (return true) only for strictly earlier times.
  /// 4. Showtimes at exactly the current time (or later) are valid (return false) — user can still book.
  /// 5. For future dates (not today and not before), return false (all enabled).
  /// 6. For past dates (before today), return true (all disabled). We also added explicit date
  ///    selection checks in the date list builder for robustness.
  ///
  /// Parsing is manual to match the existing time format without requiring extra imports at this point.
  /// Comments explain each step.
  bool isShowtimePast(String showtime, DateTime selectedDate) {
    final now = DateTime.now();

    // 1. Determine if the selected date is today (same Y/M/D as current date, per requirements)
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    if (!isToday) {
      // 6. Past dates check: normalize to date-only and compare
      final todayOnly = DateTime(now.year, now.month, now.day);
      final selOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      if (selOnly.isBefore(todayOnly)) {
        // Any showtime on a past date is past / unbookable
        return true;
      }
      // 5. Future dates: everything enabled
      return false;
    }

    // Today logic: parse showtime (as time-of-day) and compare to current wall time
    try {
      // Handle existing formats robustly: "6:00 AM", "06:00 AM", "10:30 PM", "2:30 PM" etc.
      final parts = showtime.trim().split(RegExp(r'\s+'));
      if (parts.length != 2) return false;

      final timePart = parts[0];
      String ampm = parts[1].toUpperCase();

      final timeNums = timePart.split(':');
      if (timeNums.length != 2) return false;

      int hour = int.tryParse(timeNums[0]) ?? -1;
      final minute = int.tryParse(timeNums[1]) ?? -1;

      if (hour == -1 || minute == -1 || minute < 0 || minute > 59) return false;

      // Convert 12h + AM/PM to 24h
      if (ampm == 'PM' && hour != 12) {
        hour += 12;
      } else if (ampm == 'AM' && hour == 12) {
        hour = 0;
      }
      if (hour < 0 || hour > 23) return false;

      // Construct a DateTime representing the showtime *on the selected date's day*
      // (we take Y/M/D from selectedDate but override with the parsed time; this ignores any
      // time-of-day that may be present in the selectedDate object from DateTime.now().add(...))
      final showDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        hour,
        minute,
      );

      // Truncate "now" to the minute for fair comparison (per req 4: exactly at the current time is valid).
      // This way, a showtime "3:51 PM" remains bookable for the entire 3:51 minute, even if now has seconds.
      // Only when the minute advances past the showtime's minute do we disable.
      final nowAtMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      // 3/4. isBefore (on minute resolution) means the showtime's minute has already passed today -> disable.
      // Equal minute or later minutes: allowed (user can rush).
      return showDateTime.isBefore(nowAtMinute);
    } catch (_) {
      // Fail-safe: if we can't parse, do not disable the slot
      return false;
    }
  }
}