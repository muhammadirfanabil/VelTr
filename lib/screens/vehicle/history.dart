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

  const DrivingHistory({
    super.key,
    required this.vehicleId,
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
        elevation: 0.4,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Driving History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 21,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.primaryBlue,
              size: 22,
            ),
            tooltip: "Refresh",
            onPressed: _refreshHistory,
          ),
        ],
      );
    }

    Widget buildLoading() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 2.2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading vehicles...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Something went wrong.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                onPressed: _fetchDrivingHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  textStyle: theme.textTheme.titleSmall,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  elevation: 1,
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

      return RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshHistory,
        color: AppColors.primaryBlue,
        backgroundColor: AppColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: VehicleSelectorWidget(
                selectedVehicle: _selectedVehicle,
                availableVehicles: _availableVehicles,
                isLoadingVehicles: _isLoadingVehicles,
                onTap: _showVehicleSelector,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 2,
              ),
              child: DateRangeSelectorWidget(
                selectedDays: _selectedDays,
                dayOptions: _dayOptions,
                onDaysChanged: _changeDateRange,
              ),
            ),
            if (!_isLoading && _historyEntries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6,
                ),
                child: HistoryStatisticsWidget(historyEntries: _historyEntries),
              ),
            SizedBox(
              height:
                  MediaQuery.of(context).size.height *
                  0.5, // Ensure enough height for scroll
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryBlue,
                            strokeWidth: 2.2,
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
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.backgroundSecondary],
          ),
        ),
        child: buildBody(),
      ),
    );
  }
}
