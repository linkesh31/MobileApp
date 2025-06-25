import 'dart:convert';
import 'package:http/http.dart' as http;

class ExchangeRateService {
  static const String _apiKey = 'b285077c31c7acfea2a137fa'; // Your actual key
  static const String _baseUrl = 'https://v6.exchangerate-api.com/v6';

  Future<double?> convertToUSD(double amount, String fromCurrency) async {
    try {
      final url = Uri.parse('$_baseUrl/$_apiKey/latest/$fromCurrency');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usdRate = data['conversion_rates']['USD'];
        return amount * usdRate;
      } else {
        print('Exchange API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exchange API exception: $e');
      return null;
    }
  }

  Future<double?> convertCurrency(double amount, String from, String to) async {
    try {
      final url = Uri.parse('$_baseUrl/$_apiKey/latest/$from');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = data['conversion_rates'][to];
        return amount * rate;
      } else {
        print('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception during currency conversion: $e');
      return null;
    }
  }

  Future<List<String>> getSupportedCurrencies() async {
    try {
      final url = Uri.parse('$_baseUrl/$_apiKey/latest/USD');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currencies = (data['conversion_rates'] as Map<String, dynamic>).keys.toList();
        return currencies;
      } else {
        print('Error getting currencies: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching supported currencies: $e');
      return [];
    }
  }
}
