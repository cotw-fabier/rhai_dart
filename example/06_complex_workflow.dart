/// Example 6: Complex Integration Workflow
///
/// This example demonstrates a real-world usage pattern combining:
/// - Custom engine configuration
/// - Multiple registered functions (sync)
/// - Complex script with variables, functions, and logic
/// - Comprehensive error handling
/// - Proper resource cleanup

import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Example 6: Complex Integration Workflow ===\n');
  print('Scenario: User scoring system for a gamification platform\n');

  // Step 1: Configure engine with appropriate limits
  print('Step 1: Configuring Engine');
  print('----------------------------------------');

  final config = RhaiConfig.custom(
    maxOperations: 1000000,    // Allow complex calculations
    maxStackDepth: 100,        // Allow moderate recursion
    maxStringLength: 5000000,  // ~5 MB for data processing
    timeoutMs: 5000,           // 5 second timeout
    disableFileIo: true,       // Sandbox for security
    disableEval: true,         // No dynamic code execution
    disableModules: true,      // No external modules
  );

  print('Engine configuration:');
  print('  Max operations: ${config.maxOperations}');
  print('  Timeout: ${config.timeoutMs}ms');
  print('  Sandboxed: Yes\n');

  final engine = RhaiEngine.withConfig(config);
  print('Engine created successfully.\n');

  try {
    // Step 2: Register business logic functions
    print('Step 2: Registering Business Logic Functions');
    print('----------------------------------------');

    // User data lookup
    engine.registerFunction('get_user', (int userId) {
      // Simulate database lookup
      final users = {
        1: {'name': 'Alice', 'level': 5, 'experience': 1250},
        2: {'name': 'Bob', 'level': 3, 'experience': 750},
        3: {'name': 'Charlie', 'level': 7, 'experience': 2100},
      };

      final user = users[userId];
      if (user == null) {
        throw Exception('User $userId not found');
      }
      return user;
    });
    print('Registered: get_user(userId)');

    // Calculate level from experience points
    engine.registerFunction('calculate_level', (int experience) {
      return (experience / 250).floor() + 1;
    });
    print('Registered: calculate_level(experience)');

    // Award badge based on criteria
    engine.registerFunction('award_badge', (String badgeName, int userId) {
      print('  > Awarding badge "$badgeName" to user $userId');
      return {
        'badge': badgeName,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      };
    });
    print('Registered: award_badge(badgeName, userId)');

    // Log activity
    engine.registerFunction('log_activity', (String message) {
      print('  > Log: $message');
      return true;
    });
    print('Registered: log_activity(message)');

    // Calculate bonus points
    engine.registerFunction('calculate_bonus', (List<dynamic> achievements) {
      var bonus = 0;
      for (final achievement in achievements) {
        if (achievement is Map) {
          final points = achievement['points'];
          if (points is num) {
            bonus += points.toInt();
          }
        }
      }
      return bonus;
    });
    print('Registered: calculate_bonus(achievements)');

    // Get leaderboard position
    engine.registerFunction('get_leaderboard_position', (int userId, int score) {
      // Simulate leaderboard lookup
      final positions = {
        1: 3,
        2: 7,
        3: 1,
      };
      return positions[userId] ?? 10;
    });
    print('Registered: get_leaderboard_position(userId, score)\n');

    // Step 3: Execute complex business logic script
    print('Step 3: Executing Complex Business Logic');
    print('----------------------------------------');

    final script = '''
      // User scoring and progression system
      log_activity("Starting user scoring workflow");

      // Get user data
      let user_id = 1;
      let user = get_user(user_id);
      log_activity("Processing user: " + user.name);

      // Calculate current stats
      let current_level = user.level;
      let current_exp = user.experience;
      log_activity("Current level: " + current_level + ", XP: " + current_exp);

      // Simulate earning achievements
      let achievements = [
        #{name: "First Login", points: 50},
        #{name: "Complete Tutorial", points: 100},
        #{name: "Invite Friend", points: 150},
      ];

      // Calculate total bonus
      let bonus_points = calculate_bonus(achievements);
      log_activity("Bonus points earned: " + bonus_points);

      // Update experience
      let new_exp = current_exp + bonus_points;
      let new_level = calculate_level(new_exp);

      // Check for level up
      let leveled_up = new_level > current_level;
      if leveled_up {
        log_activity("LEVEL UP! " + current_level + " -> " + new_level);
        award_badge("Level " + new_level + " Achieved", user_id);
      }

      // Calculate final score
      let final_score = new_exp + (new_level * 100);

      // Get leaderboard position
      let position = get_leaderboard_position(user_id, final_score);

      // Return comprehensive result
      #{
        user: user.name,
        old_level: current_level,
        new_level: new_level,
        leveled_up: leveled_up,
        total_experience: new_exp,
        final_score: final_score,
        achievements: achievements,
        leaderboard_position: position,
        bonus_points: bonus_points,
      }
    ''';

    print('Executing script...\n');
    final result = engine.eval(script);

    // Step 4: Process and display results
    print('\nStep 4: Processing Results');
    print('----------------------------------------');

    if (result is Map<String, dynamic>) {
      print('User Progression Results:');
      print('  User: ${result['user']}');
      print('  Level: ${result['old_level']} -> ${result['new_level']}');
      print('  Level Up: ${result['leveled_up']}');
      print('  Total XP: ${result['total_experience']}');
      print('  Final Score: ${result['final_score']}');
      print('  Bonus Points: ${result['bonus_points']}');
      print('  Leaderboard Position: #${result['leaderboard_position']}');

      final achievements = result['achievements'] as List<dynamic>;
      print('  Achievements (${achievements.length}):');
      for (final achievement in achievements) {
        if (achievement is Map) {
          print('    - ${achievement['name']}: ${achievement['points']} pts');
        }
      }
    }

    // Step 5: Test error handling with invalid user
    print('\n\nStep 5: Testing Error Handling');
    print('----------------------------------------');

    print('Attempting to process non-existent user...');
    try {
      engine.eval('''
        let user = get_user(999);
        user.name
      ''');
      print('This should not print');
    } on RhaiRuntimeError catch (e) {
      print('Caught expected error!');
      print('  Error message: ${e.message}');
    }

    // Step 6: Test operation limits with intensive script
    print('\n\nStep 6: Testing Resource Limits');
    print('----------------------------------------');

    print('Testing operation limit with intensive loop...');
    try {
      final limitResult = engine.eval('''
        let sum = 0;
        for i in 0..10000 {
          sum += i;
        }
        sum
      ''');
      print('Result within limits: $limitResult');
    } on RhaiRuntimeError catch (e) {
      print('Hit resource limit: ${e.message}');
    }

    // Step 7: Demonstrate data pipeline
    print('\n\nStep 7: Data Processing Pipeline');
    print('----------------------------------------');

    // Register data transformation functions
    engine.registerFunction('validate_score', (int score) {
      if (score < 0 || score > 10000) {
        throw Exception('Invalid score: must be between 0 and 10000');
      }
      return score;
    });

    engine.registerFunction('normalize_score', (int score, int maxScore) {
      return (score.toDouble() / maxScore.toDouble() * 100).round();
    });

    engine.registerFunction('categorize_score', (int normalizedScore) {
      if (normalizedScore >= 90) return 'Excellent';
      if (normalizedScore >= 75) return 'Good';
      if (normalizedScore >= 50) return 'Average';
      return 'Needs Improvement';
    });

    final pipelineResult = engine.eval('''
      // Data processing pipeline
      let raw_score = 1450;
      let max_score = 2100;

      // Pipeline steps
      let validated = validate_score(raw_score);
      let normalized = normalize_score(validated, max_score);
      let category = categorize_score(normalized);

      log_activity("Score pipeline: " + raw_score + " -> " + normalized + "% (" + category + ")");

      #{
        raw: raw_score,
        normalized: normalized,
        category: category,
      }
    ''');

    print('Pipeline result: $pipelineResult');

    // Step 8: Complex nested data structures
    print('\n\nStep 8: Complex Data Structures');
    print('----------------------------------------');

    engine.registerFunction('process_team', (Map<String, dynamic> team) {
      final members = team['members'] as List<dynamic>;
      final totalScore = members.fold<num>(0, (sum, member) {
        if (member is Map) {
          return sum + ((member['score'] as num?) ?? 0);
        }
        return sum;
      });

      return {
        'team': team['name'],
        'member_count': members.length,
        'total_score': totalScore,
        'average_score': (totalScore / members.length).round(),
      };
    });

    final teamResult = engine.eval('''
      let team = #{
        name: "Warriors",
        members: [
          #{name: "Alice", score: 1250},
          #{name: "Bob", score: 750},
          #{name: "Charlie", score: 2100},
        ],
      };

      process_team(team)
    ''');

    print('Team stats: $teamResult');

    print('\n=== Complex workflow completed successfully! ===');

  } on RhaiSyntaxError catch (e) {
    print('\nSyntax Error!');
    print('  Line: ${e.lineNumber}');
    print('  Message: ${e.message}');
  } on RhaiRuntimeError catch (e) {
    print('\nRuntime Error!');
    print('  Message: ${e.message}');
    if (e.stackTrace != null) {
      print('  Stack trace: ${e.stackTrace}');
    }
  } on RhaiFFIError catch (e) {
    print('\nFFI Error!');
    print('  Message: ${e.message}');
  } catch (e) {
    print('\nUnexpected Error!');
    print('  Error: $e');
  } finally {
    // Step 9: Ensure proper cleanup
    print('\n\nStep 9: Resource Cleanup');
    print('----------------------------------------');
    print('Disposing engine...');
    engine.dispose();
    print('Engine disposed: ${engine.isDisposed}');
    print('All resources cleaned up successfully.');
  }
}
