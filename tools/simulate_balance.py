"""Deterministic planning simulator, NOT a Godot runtime test.

Approximates a player who continuously hovers while actively engaged, and is
away from the can the rest of the time (shop reading, etc.). It verifies
relative progression and costs, not actual retention or play duration.

Run: python tools/simulate_balance.py --duty 0.40
"""
import argparse
import json
import random
import math
from pathlib import Path

DATA = json.loads((Path(__file__).resolve().parent.parent / 'data' / 'demo_balance.json').read_text(encoding='utf-8'))
G = DATA['gameplay']
CANS = {x['id']:x for x in DATA['cans']}
UP = {x['id']:x for x in DATA['upgrades']}
UN = {x['id']:x for x in DATA['unlocks']}


def simulate(duty=0.40, seed=7, seconds=600):
    rng = random.Random(seed)
    tick = .1
    coins = 0
    total_earned = 0
    crushed = 0
    upgrades = {k:0 for k in UP}
    unlocks = {k:False for k in UN}
    events = []
    floor_cans = []
    next_feed = G['feed_intervals_seconds'][0]
    next_stomp = 0.0
    next_auto = float('inf')

    def buy(name, cost, when):
        nonlocal coins
        assert coins >= cost, name
        coins -= cost
        assert coins >= 0
        events.append(dict(minute=round(when / 60,2), event=name, wallet=coins, crushed=crushed))

    def value_for(kind):
        return round(CANS[kind]['base_coins'] * (1 + G['coin_value_bonus_per_level'] * upgrades['value']))

    for step in range(int(seconds/tick)):
        t = step*tick
        while t + 1e-8 >= next_feed:
            r = rng.random()
            if unlocks['gold_can'] and r < G['rare_can_probability_after_unlock']:
                kind = 'gold'
            elif unlocks['blue_can'] and rng.random() < G['blue_can_probability_after_unlock']:
                kind = 'blue'
            else:
                kind = 'red'
            floor_cans.append(dict(kind=kind, hp=CANS[kind]['hp'], ready=t+1.0))
            next_feed += G['feed_intervals_seconds'][upgrades['feed_speed']]

        damage = G['initial_shoe_damage'] + upgrades['power'] * UP['power']['effect_per_level']
        ready = [c for c in floor_cans if c['ready'] <= t]
        # Approximate a player choosing the best value per remaining stomp.
        target = max(ready, key=lambda c: CANS[c['kind']]['base_coins'] / math.ceil(c['hp']/damage), default=None)
        if target is not None and t >= next_stomp:
            # Effective time dilation is an approximation of reading the shop and moving cursor away.
            cooldown = max(G['minimum_stomp_cooldown_seconds'], G['base_stomp_cooldown_seconds'] - G['stomp_cooldown_reduction_per_level']*upgrades['speed'])
            next_stomp = t + cooldown / duty
            target['hp'] -= damage
            if target['hp'] <= 0:
                payout = value_for(target['kind'])
                coins += payout
                total_earned += payout
                crushed += 1
                floor_cans.remove(target)

        if unlocks['auto_stomper'] and t >= next_auto:
            auto_cd = G['auto_interval_level2_seconds'] if upgrades['auto_speed'] else G['auto_interval_level1_seconds']
            if unlocks['conveyor']:
                auto_cd *= G['conveyor_auto_interval_multiplier']
            next_auto = t + auto_cd
            payout = value_for('red')
            coins += payout
            total_earned += payout
            crushed += 1

        def up(name, min_crushed):
            if crushed < min_crushed:
                return
            level = upgrades[name]
            if level >= len(UP[name]['costs']):
                return
            cost = UP[name]['costs'][level]
            if coins >= cost:
                buy(f'upgrade_{name}_lv{level+1}', cost, t)
                upgrades[name] += 1

        def unlock(name):
            nonlocal next_auto
            if unlocks[name] or crushed < UN[name]['requires_crushed']:
                return
            depends = UN[name].get('requires_unlock')
            if depends and not unlocks[depends]:
                return
            price = UN[name]['cost']
            if coins >= price:
                buy(f'unlock_{name}', price, t)
                unlocks[name] = True
                if name == 'auto_stomper':
                    next_auto = t + G['auto_interval_level1_seconds']

        # Sample strategy: initial throughput, value, can variety, then automation.
        if upgrades['power'] == 0:
            up('power',2)
        if upgrades['value'] == 0:
            up('value',8)
        unlock('blue_can')
        if upgrades['power'] == 1:
            up('power',25)
        if upgrades['speed'] == 0:
            up('speed',28)
        if upgrades['value'] == 1:
            up('value',42)
        unlock('gold_can')
        if upgrades['power'] == 2:
            up('power',95)
        unlock('auto_stomper')
        if unlocks['auto_stomper'] and upgrades['auto_speed'] == 0:
            up('auto_speed',145)
        unlock('conveyor')

    return dict(duty=duty, seed=seed, events=events, wallet=coins,
                total_earned=total_earned, crushed=crushed,
                upgrades=upgrades, unlocks=unlocks, floor_pending=len(floor_cans))


def validate_config():
    intervals = G['feed_intervals_seconds']
    assert len(intervals) == UP['feed_speed']['max_level']+1
    assert intervals[0] == 1 and all(x > 0 for x in intervals)
    assert all(a > b for a,b in zip(intervals,intervals[1:]))
    assert len(CANS) == 3
    for can in CANS.values():
        assert can['hp'] > 0 and can['base_coins'] > 0
    for u in UP.values():
        assert len(u['costs']) == u['max_level']
        assert all(b > a for a,b in zip(u['costs'],u['costs'][1:]))
    assert 0 < G['rare_can_probability_after_unlock'] < 1
    assert 0 < G['blue_can_probability_after_unlock'] < 1
    assert G['minimum_stomp_cooldown_seconds'] > 0
    for u in UN.values():
        assert u['cost'] > 0 and u['requires_crushed'] >= 0
        if 'requires_unlock' in u:
            assert u['requires_unlock'] in UN


if __name__ == '__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--duty', type=float, default=.40, help='Estimated active engagement ratio 0..1')
    ap.add_argument('--seed', type=int, default=7)
    ap.add_argument('--seconds', type=int, default=600)
    args=ap.parse_args()
    if not (0 < args.duty <= 1):
        ap.error('--duty must be >0 and <=1')
    validate_config()
    result=simulate(args.duty,args.seed,args.seconds)
    print('Demo economy simulation (NOT real playtest):')
    for e in result['events']:
        print(f"{e['minute']:5.2f}m  {e['event']:<27} wallet={e['wallet']:<5} crushed={e['crushed']}")
    print('Summary:', json.dumps({k:result[k] for k in ['wallet','total_earned','crushed','unlocks']},ensure_ascii=False))
