export function scoreRound(players, submissions, votes) {
  const scores = Object.fromEntries(
    players.map((id) => [id, { correct: 0, bluff: 0, total: 0 }]),
  );
  const validVotes = new Map();
  for (const vote of votes) {
    if (scores[vote.voterId] && !validVotes.has(vote.voterId))
      validVotes.set(vote.voterId, vote.targetId);
  }
  for (const [voterId, targetId] of validVotes) {
    if (targetId === "truth") scores[voterId].correct = 3;
    const bluffAuthor = submissions.find(
      (submission) => submission.playerId === targetId,
    )?.playerId;
    if (bluffAuthor && bluffAuthor !== voterId && scores[bluffAuthor])
      scores[bluffAuthor].bluff += 2;
  }
  for (const score of Object.values(scores))
    score.total = score.correct + score.bluff;
  return scores;
}

export function isValidFakeAnswer(value) {
  const answer = String(value ?? "").trim();
  return answer.length >= 2 && answer.length <= 120;
}

export function shuffleAnswers(answers, random = Math.random) {
  const copy = [...answers];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}
