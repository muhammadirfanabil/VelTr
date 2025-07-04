import 'package:flutter/material.dart';
import '../../services/history/history_service.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../models/vehicle/vehicle.dart';

import '../../widgets/history/vehicle_selector_widget.dart';
import '../../widgets/history/vehicle_selection_modal.dart';
import '../../widgets/history/date_range_selector_widget.dart';
import '../../widgets/history/history_statistics_widget.dart';
import '../../widgets/history/history_list_widget.dart';
import '../../widgets/history/empty_state_widgets.dart';
import '../../theme/app_colors.dart';

class DrivingHistory extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;
  final DateTime? createdAt;

  const DrivingHistory({
    super.key,
    required this.vehicleId,
    required this.createdAt,
    required this.vehicleName,
  });

  @override
  State<DrivingHistory> createState() => _DrivingHistoryState();
}

class _DrivingHistoryState extends State<DrivingHistory> {
  bool _isLoading = true;
  String? _error;
  List<HistoryEntry> _historyEntries = [];
  int _selectedDays = 7;
  final List<int> _dayOptions = [1, 3, 7];

  vehicle? _selectedVehicle;
  List<vehicle> _availableVehicles = [];
  bool _isLoadingVehicles = false;
  final VehicleService _vehicleService = VehicleService();

  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _initializeVehicleAndHistory();
  }

  Future<void> _initializeVehicleAndHistory() async {
    await _loadVehicles();

    if (_availableVehicles.isNotEmpty) {
      if (widget.vehicleId.isNotEmpty) {
        _selectedVehicle = _availableVehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => _availableVehicles.first,
        );
      } else {
        _selectedVehicle = _availableVehicles.first;
      }
    }

    await _fetchDrivingHistory();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final vehicles = await _vehicleService.getVehiclesStream().first;
      setState(() {
        _availableVehicles = vehicles;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      setState(() {
        _availableVehicles = [];
        _isLoadingVehicles = false;
      });
    }
  }

  Future<void> _fetchDrivingHistory() async {
    if (_selectedVehicle == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await HistoryService.fetchDrivingHistory(
        vehicleId: _selectedVehicle!.id,
        days: _selectedDays,
      );
      setState(() {
        _historyEntries = entries;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHistory() async {
    await _loadVehicles();
    await _fetchDrivingHistory();
  }

  void _changeDateRange(int days) {
    if (_selectedDays != days) {
      setState(() {
        _selectedDays = days;
      });
      _fetchDrivingHistory();
    }
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => VehicleSelectionModal(
            availableVehicles: _availableVehicles,
            selectedVehicle: _selectedVehicle,
            isLoadingVehicles: _isLoadingVehicles,
            onVehicleSelected: _selectVehicle,
          ),
    );
  }

  void _selectVehicle(vehicle newVehicle) {
    if (_selectedVehicle?.id != newVehicle.id) {
      setState(() {
        _selectedVehicle = newVehicle;
      });
      _fetchDrivingHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    PreferredSizeWidget buildAppBar() {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.only(left: 6),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              // decoration: BoxDecoration(
              //   color: AppColors.surface,
              //   borderRadius: BorderRadius.circular(12),
              //   boxShadow: [
              //     BoxShadow(
              //       color: AppColors.textPrimary.withValues(alpha: 0.06),
              //       blurRadius: 10,
              //       offset: const Offset(0, 2),
              //     ),
              //   ],
              // ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: Text(
          'Driving History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                // decoration: BoxDecoration(
                //   color: AppColors.surface,
                //   borderRadius: BorderRadius.circular(12),
                //   boxShadow: [
                //     BoxShadow(
                //       color: AppColors.primaryBlue.withValues(alpha: 0.06),
                //       blurRadius: 10,
                //       offset: const Offset(0, 2),
                //     ),
                //   ],
                // ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              onPressed: _refreshHistory,
            ),
          ),
        ],
      );
    }

    Widget buildLoading() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryBlue,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading vehicles...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildEmptyVehicles() {
      return VehicleEmptyStateWidget(
        onAddVehicle: () {
          Navigator.pushNamed(context, '/manage-vehicle');
        },
      );
    }

    Widget buildVehiclePrompt() {
      return const VehicleSelectionPromptWidget();
    }

    Widget buildError() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Please try again later',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                onPressed: _fetchDrivingHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.surface,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildBody() {
      if (_isLoadingVehicles) return buildLoading();
      if (_availableVehicles.isEmpty) return buildEmptyVehicles();
      if (_selectedVehicle == null) return buildVehiclePrompt();

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundPrimary,
              AppColors.backgroundSecondary,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _refreshHistory,
          color: AppColors.primaryBlue,
          backgroundColor: AppColors.surface,
          strokeWidth: 2.5,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: VehicleSelectorWidget(
                  selectedVehicle: _selectedVehicle,
                  availableVehicles: _availableVehicles,
                  isLoadingVehicles: _isLoadingVehicles,
                  onTap: _showVehicleSelector,
                ),
              ),
              // const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DateRangeSelectorWidget(
                  selectedDays: _selectedDays,
                  dayOptions: _dayOptions,
                  onDaysChanged: _changeDateRange,
                ),
              ),
              if (!_isLoading && _historyEntries.isNotEmpty) ...[
                // const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: HistoryStatisticsWidget(
                    historyEntries: _historyEntries,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child:
                      _isLoading
                          ? Center(
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.06,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryBlue,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          )
                          : _error != null
                          ? buildError()
                          : HistoryListWidget(
                            historyEntries: _historyEntries,
                            isLoading: _isLoading,
                            error: _error,
                          ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      extendBodyBehindAppBar: true,
      appBar: buildAppBar(),
      body: SafeArea(child: buildBody()),
    );
  }
}
