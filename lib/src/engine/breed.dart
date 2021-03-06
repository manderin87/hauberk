import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import 'ai/move.dart';
import 'attack.dart';
import 'energy.dart';
import 'game.dart';
import 'hero/hero.dart';
import 'items/item.dart';
import 'log.dart';
import 'monster.dart';
import 'option.dart';

/// A single kind of [Monster] in the game.
class Breed {
  final Pronoun pronoun;
  String get name => Log.singular(_name);

  /// Untyped so the engine isn't coupled to how monsters appear.
  final appearance;

  /// The breeds's depth.
  ///
  /// Higher depth breeds are found later in the game.
  final int depth;

  final List<Attack> attacks;
  final List<Move>   moves;

  final int maxHealth;

  /// How well the monster can navigate the stage to reach its target.
  ///
  /// Used to determine maximum pathfinding distance.
  final int tracking;

  /// How much randomness the monster has when walking towards its target.
  final int meander;

  /// The breed's speed, relative to normal. Ranges from `-6` (slowest) to `6`
  /// (fastest) where `0` is normal speed.
  final int speed;

  /// The [Item]s this monster may drop when killed.
  final Drop drop;

  final Set<String> flags;

  /// The name of the breed. If the breed's name has irregular pluralization
  /// like "bunn[y|ies]", this will be the original unparsed string.
  final String _name;

  Breed(this._name, this.pronoun, this.appearance, this.attacks, this.moves,
      this.drop, {
      this.depth, this.maxHealth, this.tracking, this.meander, this.speed,
      this.flags});

  /// How much experience a level one [Hero] gains for killing a [Monster] of
  /// this breed.
  int get experienceCents {
    // The more health it has, the longer it can hurt the hero.
    var exp = maxHealth.toDouble();

    // Faster monsters are worth more.
    exp *= Energy.gains[Energy.normalSpeed + speed];

    // Average the attacks (since they are selected randomly) and factor them
    // in.
    var attackTotal = 0.0;
    for (var attack in attacks) {
      // TODO: Take range into account?
      attackTotal += attack.damage * Option.expElement[attack.element];
    }

    attackTotal /= attacks.length;

    var moveTotal = 0.0;
    var moveRateTotal = 0.0;
    for (var move in moves) {
      // Scale by the move rate. The less frequently a move can be performed,
      // the less it affects experience.
      moveTotal += move.experience / move.rate;

      // Magify the rate to roughly account for the fact that a move may not be
      // applicable all the time.
      moveRateTotal += 1 / (move.rate * 2);
    }

    // A monster can only do one thing each turn, so even if the move rates
    // are better than than, limit it.
    moveRateTotal = math.min(1.0, moveRateTotal);

    // Time spent using moves is not time spent attacking.
    attackTotal *= (1.0 - moveRateTotal);

    // Add in moves and attacks.
    exp *= attackTotal + moveTotal;

    // Take into account flags.
    for (var flag in flags) {
      exp *= Option.expFlag[flag];
    }

    // Meandering monsters are worth less.
    exp *= (Option.expMeander - meander) / Option.expMeander;

    return exp.toInt();
  }

  /// When a [Monster] of this Breed is generated, how many of the same type
  /// should be spawned together (roughly).
  int get numberInGroup {
    if (flags.contains('horde')) return 12;
    if (flags.contains('swarm')) return 8;
    if (flags.contains('pack')) return 6;
    if (flags.contains('group')) return 4;
    if (flags.contains('few')) return 2;
    return 1;
  }

  Monster spawn(Game game, Vec pos, [Monster parent]) {
    var generation = 1;
    if (parent != null) generation = parent.generation + 1;

    return new Monster(game, this, pos.x, pos.y, maxHealth, generation);
  }
}
