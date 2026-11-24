import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LoadFailure implements Exception {
  final String message;
  const LoadFailure(this.message);
}

class Breed {
  final String name;
  final String description;
  final Map<String, String> facts;
  const Breed(this.name, this.description, this.facts);

  factory Breed.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const LoadFailure('У породы отсутствует название.');
    }
    const labels = {
      'origin': 'Страна',
      'temperament': 'Темперамент',
      'life_span': 'Продолжительность жизни, лет',
      'weight': 'Вес, кг',
      'breed_group': 'Группа породы',
      'history': 'История',
      'bred_for': 'Назначение',
      'perfect_for': 'Кому подойдёт',
      'country_code': 'Код страны',
      'alt_names': 'Другие названия',
      'country_codes': 'Код страны',
      'adaptability': 'Адаптивность',
      'affection_level': 'Ласковость',
      'child_friendly': 'Отношение к детям',
      'dog_friendly': 'Отношение к собакам',
      'energy_level': 'Энергичность',
      'grooming': 'Потребность в уходе',
      'health_issues': 'Склонность к заболеваниям',
      'intelligence': 'Интеллект',
      'shedding_level': 'Линька',
      'social_needs': 'Потребность в общении',
      'stranger_friendly': 'Отношение к незнакомцам',
      'vocalisation': 'Разговорчивость',
      'hypoallergenic': 'Гипоаллергенность',
      'indoor': 'Домашняя порода',
      'lap': 'Любит сидеть на коленях',
      'experimental': 'Экспериментальная порода',
      'hairless': 'Бесшёрстная',
      'natural': 'Природная порода',
      'rare': 'Редкая',
      'rex': 'Кудрявая шерсть',
      'suppressed_tail': 'Короткий хвост',
      'short_legs': 'Короткие лапы',
      'wikipedia_url': 'Википедия',
      'cfa_url': 'CFA',
      'vetstreet_url': 'Vetstreet',
      'vcahospitals_url': 'VCA',
      'cat_friendly': 'Отношение к кошкам',
      'bidability': 'Обучаемость',
    };
    final facts = <String, String>{};
    for (final entry in labels.entries) {
      var value = json[entry.key];
      if (value is Map) value = value['metric'];
      if (value != null && value.toString().trim().isNotEmpty) {
        facts[entry.value] = value.toString();
      }
    }
    return Breed(name, json['description']?.toString() ?? '', facts);
  }
}

class Cat {
  final Uri photo;
  final Breed breed;
  const Cat(this.photo, this.breed);
}

class CatApi {
  final http.Client client;
  final String key;
  final String base;
  CatApi(
    this.client, {
    this.key = const String.fromEnvironment('CAT_API_KEY'),
    this.base = const String.fromEnvironment(
      'CAT_API_BASE_URL',
      defaultValue: 'https://api.thecatapi.com/v1',
    ),
  });

  Future<List<dynamic>> _get(String path) async {
    if (key.trim().isEmpty) {
      throw const LoadFailure(
        'Для загрузки нужен ключ TheCatAPI. Укажите CAT_API_KEY при сборке.',
      );
    }
    try {
      final uri = Uri.parse(base.replaceFirst(RegExp(r'/+$'), '') + path);
      if (uri.scheme != 'https') {
        throw const LoadFailure('Для подключения нужен адрес HTTPS.');
      }
      final response = await client
          .get(uri, headers: {'x-api-key': key})
          .timeout(const Duration(seconds: 12));
      if ([401, 403].contains(response.statusCode)) {
        throw const LoadFailure('TheCatAPI отклонил ключ доступа.');
      }
      if (response.statusCode != 200) {
        throw const LoadFailure('Сервис временно недоступен.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty) {
        throw const LoadFailure('Сервис вернул пустой список.');
      }
      return data;
    } on TimeoutException {
      throw const LoadFailure('Сервис долго не отвечает.');
    } on http.ClientException {
      throw const LoadFailure('Нет связи с сервисом. Проверьте интернет.');
    } on FormatException {
      throw const LoadFailure('Не удалось прочитать ответ сервиса.');
    }
  }

  Future<Cat> next() async {
    final item = (await _get('/images/search?has_breeds=1')).first;
    if (item is! Map || item['breeds'] is! List) {
      throw const LoadFailure('Кот без сведений о породе.');
    }
    final breeds = item['breeds'] as List;
    if (breeds.isEmpty || breeds.first is! Map<String, dynamic>) {
      throw const LoadFailure('Кот без сведений о породе.');
    }
    final photo = Uri.tryParse(item['url']?.toString() ?? '');
    if (photo == null || photo.scheme != 'https' || photo.host.isEmpty) {
      throw const LoadFailure('У кота нет доступного фото.');
    }
    return Cat(photo, Breed.fromJson(breeds.first as Map<String, dynamic>));
  }

  Future<List<Breed>> breeds() async {
    final rows = await _get('/breeds');
    return rows.map((row) {
      if (row is! Map<String, dynamic>) {
        throw const LoadFailure('Не удалось прочитать каталог.');
      }
      return Breed.fromJson(row);
    }).toList();
  }
}
