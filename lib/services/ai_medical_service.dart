import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';
import '../models/bracelet_model.dart';

class AiMedicalService {
  // L'URL de TON serveur Render
  static const String _backendUrl = 'https://fall-detection-backend-7w0h.onrender.com/api/generate-report';

  Future<String> generateMedicalReport(AlertModel alert) async {
    // 1. Récupération des données exactes du patient
    int patientAge = 0;
    String conditions = 'Aucun';
    String meds = 'Aucun';

    try {
      final braceletDoc = await FirebaseFirestore.instance
          .collection('bracelets')
          .doc(alert.braceletId)
          .get();

      if (braceletDoc.exists) {
        final bracelet = BraceletModel.fromFirestore(braceletDoc);
        patientAge = bracelet.patientAge ?? 0;
        conditions = (bracelet.medicalConditions?.isNotEmpty ?? false) ? bracelet.medicalConditions! : 'Aucun';
        meds = (bracelet.medications?.isNotEmpty ?? false) ? bracelet.medications! : 'Aucun';
      }
    } catch (e) {
      print('Erreur lecture profil: $e');
    }

    final temp = alert.weather?.temperature ?? 'Inconnue';
    final weatherDesc = alert.weather?.description ?? 'Inconnue';

    // 2. Le Prompt hyper précis pour l'IA
    final prompt = '''
Tu es un médecin urgentiste expert en traumatologie liée aux chutes des personnes âgées.
Un soignant vient de recevoir une alerte de chute via notre bracelet connecté.

Patient : ${alert.patientName}
Âge : $patientAge ans
Antécédents médicaux : $conditions
Médicaments en cours : $meds
Météo au moment de la chute : $temp°C, $weatherDesc.
Heure de la chute : ${alert.formattedDate}

Rédige un rapport médical urgent et très court pour le soignant qui va intervenir. 
Le rapport doit être structuré exactement ainsi :
• Risques immédiats (selon le profil médical).
• Risques environnementaux (selon la météo).
• 3 actions prioritaires à faire en arrivant sur place.

Sois direct, professionnel, utilise des puces et ne fais aucune phrase d'introduction.
''';

    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"prompt": prompt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reportText = data['report']; // Le texte de Gemini

        //  SAUVEGARDE DANS FIRESTORE
        await FirebaseFirestore.instance
            .collection('alerts')
            .doc(alert.id)
            .update({
          'aiReport': reportText,
        });

        return reportText;
      } else {
        return 'Erreur du serveur (Code ${response.statusCode}).';
      }
    } catch (e) {
      return 'Impossible de contacter le serveur.';
    }
  }
}