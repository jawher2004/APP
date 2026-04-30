import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/alert_model.dart';
import '../../services/ai_medical_service.dart';

class AlertDetailsScreen extends StatefulWidget {
  final AlertModel alert;

  const AlertDetailsScreen({super.key, required this.alert});

  @override
  State<AlertDetailsScreen> createState() => _AlertDetailsScreenState();
}

class _AlertDetailsScreenState extends State<AlertDetailsScreen> {
  final _aiService = AiMedicalService();

  bool _isGeneratingAI = false;
  String? _aiReport;

  //  CHARGER LE RAPPORT SAUVEGARDÉ AU DÉMARRAGE
  @override
  void initState() {
    super.initState();
    // On enlève les doubles étoiles "**" que l'IA met pour le gras, pour faire plus propre
    _aiReport = widget.alert.aiReport?.replaceAll('**', '');
  }

  Future<void> _generateAIReport() async {
    setState(() => _isGeneratingAI = true);

    final report = await _aiService.generateMedicalReport(widget.alert);

    if (mounted) {
      setState(() {
        _aiReport = report.replaceAll('**', ''); // On nettoie les étoiles ici aussi
        _isGeneratingAI = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Détails de l\'alerte'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (widget.alert.weather != null) _buildWeatherCard(widget.alert.weather!),
            const SizedBox(height: 16),

            //  SECTION INTELLIGENCE ARTIFICIELLE
            _buildAiSection(),

            const SizedBox(height: 16),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  // --- SECTION IA ---
  Widget _buildAiSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple[200]!, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple[600]),
              const SizedBox(width: 8),
              const Text('Assistant Médical IA',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 24),

          if (_aiReport == null) ...[
            const Text(
              'L\'IA peut analyser le profil du patient et l\'environnement pour vous guider avant l\'intervention.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingAI ? null : _generateAIReport,
                icon: _isGeneratingAI
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics),
                label: Text(_isGeneratingAI ? 'Analyse en cours...' : 'Générer le rapport prioritaire'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            // Affichage du rapport généré
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _aiReport!,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _generateAIReport,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Régénérer'),
              style: TextButton.styleFrom(foregroundColor: Colors.purple[700]),
            ),
          ],
        ],
      ),
    );
  }

  // --- RESTE DU CODE INCHANGÉ ---

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                child: Icon(Icons.warning_rounded, color: Colors.red[600], size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chute détectée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(DateFormat('dd/MM/yyyy à HH:mm:ss').format(widget.alert.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Patient : ${widget.alert.patientName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(WeatherData weather) {
    final riskColor = _getRiskColor(weather.riskLevel);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text('Environnement lors de la chute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Image.network('https://openweathermap.org/img/wn/${weather.icon}@2x.png', width: 64, height: 64, errorBuilder: (_, __, ___) => Icon(Icons.wb_sunny, size: 40, color: riskColor)),
                  Text('${weather.temperature}°C', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: riskColor)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _weatherRow(Icons.location_on,
                        weather.country.isNotEmpty
                            ? '${weather.city}, ${weather.country}'
                            : weather.city
                    ),
                    _weatherRow(Icons.thermostat, 'Ressenti ${weather.feelsLike}°C'),
                    _weatherRow(Icons.water_drop, 'Humidité ${weather.humidity}%'),
                    _weatherRow(Icons.description, weather.description),
                  ],
                ),
              ),
            ],
          ),
          if (weather.riskLevel != 'normal') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: riskColor.withOpacity(0.3))),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: riskColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_getRiskAdvice(weather.riskLevel, weather.temperature), style: TextStyle(color: riskColor, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weatherRow(IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(icon, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 14))]));
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations techniques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 24),
          Text('ID Alerte : ${widget.alert.id}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          Text('ID Bracelet : ${widget.alert.braceletId}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    if (riskLevel == 'hypothermie') return Colors.blue[700]!;
    if (riskLevel == 'hyperthermie') return Colors.red[600]!;
    if (riskLevel == 'canicule') return Colors.orange[700]!;
    return Colors.green[600]!;
  }

  String _getRiskAdvice(String riskLevel, int temp) {
    if (riskLevel == 'hypothermie') return 'Risque d\'hypothermie ($temp°C). Couvrir le patient.';
    if (riskLevel == 'hyperthermie') return 'Risque de coup de chaleur ($temp°C). Hydrater le patient.';
    if (riskLevel == 'canicule') return 'Canicule. Risque de déshydratation rapide.';
    return '';
  }
}