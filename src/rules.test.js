import { describe, expect, it } from 'vitest';
import { isValidFakeAnswer, scoreRound, shuffleAnswers } from './rules.js';

describe('game rules reference cases', () => {
  it('awards 3 for truth and 2 to the bluff author for each opponent fooled', () => {
    const result = scoreRound(['alice','bob','cy'],[
      {playerId:'alice',answer:'A moon made of cheese'},
      {playerId:'bob',answer:'A tiny underground orchestra'},
    ],[
      {voterId:'alice',targetId:'truth'},
      {voterId:'bob',targetId:'alice'},
      {voterId:'cy',targetId:'alice'},
    ]);
    expect(result.alice).toEqual({correct:3,bluff:4,total:7});
    expect(result.bob).toEqual({correct:0,bluff:0,total:0});
    expect(result.cy).toEqual({correct:0,bluff:0,total:0});
  });
  it('never rewards a player for selecting their own bluff and deduplicates voters', () => {
    const result = scoreRound(['alice','bob'],[
      {playerId:'alice',answer:'A self-selected lie'},
      {playerId:'bob',answer:'A plausible lie'},
    ],[
      {voterId:'alice',targetId:'alice'},
      {voterId:'alice',targetId:'truth'},
      {voterId:'bob',targetId:'truth'},
    ]);
    expect(result.alice.total).toBe(0);
    expect(result.bob.correct).toBe(3);
  });
  it('accepts only trimmed answers from 2 to 120 characters', () => {
    expect(isValidFakeAnswer('  ok ')).toBe(true);
    expect(isValidFakeAnswer(' ')).toBe(false);
    expect(isValidFakeAnswer('x'.repeat(121))).toBe(false);
  });
  it('shuffles all choices, including the correct answer position', () => {
    const values=['fake-a','fake-b','truth'];
    const result=shuffleAnswers(values,()=>0);
    expect(result).toEqual(['fake-b','truth','fake-a']);
    expect(result).toHaveLength(3);
  });
});

