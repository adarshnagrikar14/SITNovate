class ApiConstants {
  static const String baseUrl = 'http://192.168.190.172:5000';
  static const String animationEndpoint = '$baseUrl/create_animation';

  // API Endpoints
  static const String chatEndpoint = '/chat';
  static const String learningEndpoint = '/learning';
  static const String characterEndpoint = '/character';
  static const String storyEndpoint = '/story';
}

/**
 * curl --location 'http://192.168.190.172:5000/create_animation' \
--header 'Content-Type: application/json' \
--data '{
    "prompt": "area of circle"
}'
 */
