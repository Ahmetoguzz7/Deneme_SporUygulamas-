import 'package:EVOM_SPOR/core/app_repository.dart';
import 'package:EVOM_SPOR/versionfooter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class VeliOdemeSayfasi extends StatefulWidget {
  final Users cocuk;
  const VeliOdemeSayfasi({super.key, required this.cocuk});

  @override
  State<VeliOdemeSayfasi> createState() => _VeliOdemeSayfasiState();
}

class _VeliOdemeSayfasiState extends State<VeliOdemeSayfasi> {
  late Future<Map<String, dynamic>> _paymentsDataFuture;

  List<Payment> tumOdemeler = [];
  List<Payment> filtrelenmisOdemeler = [];

  String _selectedFilter = "Son 6 Ay";
  final List<String> _filterOptions = [
    "Son 3 Ay",
    "Son 6 Ay",
    "Son 1 Yıl",
    "Tümü",
  ];

  bool _isInitialLoad = true;

  // =========================================================================
  // 🔥 TÜRKÇE TARİH FONKSİYONLARI
  // =========================================================================

  String _formatDateTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatShortDateTurkish(String dateStr) {
    if (dateStr.isEmpty) return "Belirsiz";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getMonthFromDateTurkish(String dateStr) {
    if (dateStr.isEmpty) return "?";
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('MMMM yyyy', 'tr_TR');
      return formatter.format(date);
    } catch (e) {
      return dateStr.substring(0, 7);
    }
  }

  String _getShortMonthName(int month) {
    const months = [
      "Oca",
      "Şub",
      "Mar",
      "Nis",
      "May",
      "Haz",
      "Tem",
      "Ağu",
      "Eyl",
      "Eki",
      "Kas",
      "Ara",
    ];
    return months[month - 1];
  }

  // 🚀 HIZLANDIRILMIŞ VERİ YÜKLEME (CACHE KULLANIMI)
  // 🚀 KİLİTSİZ 0MS ÖDEME GETİRME MOTORU
  Future<Map<String, dynamic>> _odemeleriGetir() async {
    final repo = AppRepository();

    if (!repo.isLoaded) {
      await repo.loadCriticalData();
    }

    // Doğrudan RAM'den bu çocuğun ödemelerini filtrele çek kanka
    final odemelerList = repo
        .getPaymentsByStudentId(widget.cocuk.app)
        .where((p) => p.status.toLowerCase() == "paid")
        .toList();

    odemelerList.sort((a, b) => b.paid_date.compareTo(a.paid_date));

    tumOdemeler = odemelerList;
    filtrelenmisOdemeler = _getFilteredPayments(tumOdemeler, _selectedFilter);

    double totalPaid = 0;
    for (var p in tumOdemeler) {
      totalPaid += double.tryParse(p.amount) ?? 0;
    }

    _isInitialLoad = false;

    return {'payments': filtrelenmisOdemeler, 'totalPaid': totalPaid};
  }

  // 🔥 DÜZELTİLDİ - setState kullanmadan direkt değer döndür
  List<Payment> _getFilteredPayments(List<Payment> payments, String filter) {
    final now = DateTime.now();
    DateTime startDate;

    switch (filter) {
      case "Son 3 Ay":
        startDate = now.subtract(const Duration(days: 90));
        break;
      case "Son 6 Ay":
        startDate = now.subtract(const Duration(days: 180));
        break;
      case "Son 1 Yıl":
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        startDate = DateTime(2000);
    }

    if (filter == "Tümü") {
      return List.from(payments);
    } else {
      return payments.where((p) {
        try {
          final date = DateTime.parse(p.paid_date);
          return date.isAfter(startDate);
        } catch (e) {
          return false;
        }
      }).toList();
    }
  }

  double _getTotalAmount() {
    return filtrelenmisOdemeler.fold(
      0,
      (sum, p) => sum + (double.tryParse(p.amount) ?? 0),
    );
  }

  Map<String, double> _getMonthlyPayments() {
    Map<String, double> monthly = {};
    for (var p in filtrelenmisOdemeler) {
      try {
        final date = DateTime.parse(p.paid_date);
        final monthKey = DateFormat('yyyy-MM').format(date);
        final amount = double.tryParse(p.amount) ?? 0;
        monthly[monthKey] = (monthly[monthKey] ?? 0) + amount;
      } catch (e) {
        continue;
      }
    }
    return monthly;
  }

  @override
  void initState() {
    super.initState();
    _paymentsDataFuture = _odemeleriGetir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.cocuk.first_name} ${widget.cocuk.last_name}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text("Ödeme Geçmişi", style: TextStyle(fontSize: 12)),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
                // 🔥 Filtreyi mevcut verilere uygula
                filtrelenmisOdemeler = _getFilteredPayments(
                  tumOdemeler,
                  _selectedFilter,
                );
              });
            },
            itemBuilder: (context) => _filterOptions.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      filter == _selectedFilter
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: filter == _selectedFilter
                          ? Colors.teal
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(filter),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _paymentsDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          }

          if (snapshot.hasError || (snapshot.data?['success'] == false)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Hata: ${snapshot.error ?? snapshot.data?['error']}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _paymentsDataFuture = _odemeleriGetir();
                        _isInitialLoad = true;
                      });
                    },
                    child: const Text("Tekrar Dene"),
                  ),
                ],
              ),
            );
          }

          final odemelerList =
              snapshot.data?['payments'] as List<Payment>? ?? [];

          // 🔥 DÜZELTİLDİ - setState kullanmadan direkt state değişkenlerini güncelle
          if (_isInitialLoad || odemelerList != tumOdemeler) {
            tumOdemeler = odemelerList;
            filtrelenmisOdemeler = _getFilteredPayments(
              tumOdemeler,
              _selectedFilter,
            );
            _isInitialLoad = false;
          }

          if (filtrelenmisOdemeler.isEmpty) {
            return _buildEmptyState();
          }

          final totalAmount = _getTotalAmount();
          final monthlyPayments = _getMonthlyPayments();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _paymentsDataFuture = _odemeleriGetir();
                _isInitialLoad = true;
              });
              await _paymentsDataFuture;
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_list,
                              size: 14,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedFilter,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${filtrelenmisOdemeler.length} ödeme",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              size: 48,
                              color: Colors.teal,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Toplam Ödenen",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${totalAmount.toStringAsFixed(2)} TL",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoItem(
                                    "Ödeme Sayısı",
                                    filtrelenmisOdemeler.length.toString(),
                                    Icons.receipt,
                                  ),
                                  _buildInfoItem(
                                    "Ortalama",
                                    "${(totalAmount / filtrelenmisOdemeler.length).toStringAsFixed(0)} TL",
                                    Icons.trending_up,
                                  ),
                                ],
                              ),
                            ),
                            const VersionFooter(),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      if (monthlyPayments.isNotEmpty)
                        _buildMonthlyChart(monthlyPayments),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 20, color: Colors.teal),
                            SizedBox(width: 8),
                            Text(
                              "Ödeme Geçmişi",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final o = filtrelenmisOdemeler[index];
                    final amount = double.tryParse(o.amount) ?? 0;
                    return _buildPaymentCard(o, amount);
                  }, childCount: filtrelenmisOdemeler.length),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 16),
          Text("Ödeme bilgileri yükleniyor..."),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart(Map<String, double> monthlyPayments) {
    var sortedMonths = monthlyPayments.keys.toList()..sort();
    double maxPayment = monthlyPayments.values.isEmpty
        ? 1
        : monthlyPayments.values.reduce((a, b) => a > b ? a : b);
    double maxBarHeight = 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.teal, size: 22),
              SizedBox(width: 8),
              Text(
                "Aylık Ödeme Grafiği",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                final month = sortedMonths[index];
                final amount = monthlyPayments[month] ?? 0;
                final barHeight = maxPayment > 0
                    ? (amount / maxPayment) * maxBarHeight
                    : 0;

                final monthNum = int.parse(month.split('-')[1]);
                final monthName = _getShortMonthName(monthNum);
                final year = month.split('-')[0];

                return Container(
                  width: 70,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 35,
                        height: maxBarHeight,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        monthName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        year,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "${amount.toStringAsFixed(0)}₺",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Payment o, double amount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.receipt_long, color: Colors.teal, size: 28),
        ),
        title: Text(
          _getMonthFromDateTurkish(o.paid_date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ödeme Tarihi: ${_formatShortDateTurkish(o.paid_date)}",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (o.payment_method.isNotEmpty)
              Text(
                "Yöntem: ${o.payment_method}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (o.note.isNotEmpty)
              Text(
                o.note,
                style: const TextStyle(fontSize: 11, color: Colors.teal),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${amount.toStringAsFixed(0)} TL",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz Ödeme Kaydı Bulunmuyor",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.cocuk.first_name} için henüz ödeme yapılmamış",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
