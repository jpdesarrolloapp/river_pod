import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('caches the provider per value', () {
    final family = Provider.family<String, int>((ref, a) => '$a');
    final container = ProviderContainer();

    expect(family(42), family(42));
    expect(container.read(family(42)), '42');

    expect(family(21), family(21));
    expect(container.read(family(21)), '21');
  });
  test('each provider updates their dependents independently', () {
    final controllers = {
      0: StreamController<String>(sync: true),
      1: StreamController<String>(sync: true),
    };
    final family = StreamProvider.family<String, int>((ref, a) {
      return controllers[a].stream;
    });
    final container = ProviderContainer();
    final listener = Listener<AsyncValue<String>>();
    final listener2 = Listener<AsyncValue<String>>();

    family(0).watchOwner(container, listener);
    verify(listener(const AsyncValue.loading()));
    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);

    family(1).watchOwner(container, listener2);
    verify(listener2(const AsyncValue.loading()));
    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);

    controllers[0].add('42');

    verify(listener(const AsyncValue.data('42')));
    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);

    controllers[1].add('21');

    verify(listener2(const AsyncValue.data('21')));
    verifyNoMoreInteractions(listener);
    verifyNoMoreInteractions(listener2);
  });
  test('Pass family and argument properties', () {
    final family =
        StateNotifierProvider.family<Counter, int>((_, a) => Counter());
    expect(
      family(0),
      isA<StateNotifierProvider<Counter>>()
          .having((p) => p.argument, 'argument', 0)
          .having((p) => p.from, 'from', family),
    );
    expect(
      family(1),
      isA<StateNotifierProvider<Counter>>()
          .having((p) => p.from, 'from', family)
          .having((p) => p.argument, 'argument', 1),
    );
  });

  test('family override', () {
    final family = Provider.family<String, int>((ref, a) => '$a');
    final container = ProviderContainer(overrides: [
      // Provider overrides always takes over family overrides
      family(84).overrideAs(Provider((_) => 'Bonjour 84')),
      family.overrideAs((ref, a) => 'Hello $a'),
      family(21).overrideAs(Provider((_) => 'Hi 21')),
    ]);

    expect(container.read(family(21)), 'Hi 21');
    expect(container.read(family(84)), 'Bonjour 84');
    expect(container.read(family(42)), 'Hello 42');
  });
}

class Listener<T> extends Mock {
  void call(T value);
}

class Counter extends StateNotifier<int> {
  Counter([int initialValue = 0]) : super(initialValue);

  @override
  int get state => super.state;
  @override
  set state(int value) => super.state = value;
}
