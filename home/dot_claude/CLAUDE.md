## 開発スタイル

TDD で開発する（探索 → Red → Green → Refactoring）。
KPI やカバレッジ目標が与えられたら、達成するまで試行する。
不明瞭な指示は質問して明確にする。

## Git

作業の区切りがついた段階で毎回コミットする。
コードの変更量が多い場合や複数機能に跨る場合は、各 PR が最小限になるよう [stacked pull requests](https://docs.github.com/pull-requests/how-tos/stacked-pull-requests) を積極的に利用する。

## コメント・ドキュメント

コード上のコメントやドキュメントは必要最小限とする

### 書く方針
- コードを読んでも理解できないこと（Why/Why not）
- 詳細な仕様はテストコードで表現する

### 書かない方針
- コードを読めば理解できること(What/How)

## コード設計

- 関心の分離を保つ
- 状態とロジックを分離する
- 可読性と保守性を重視する
- コントラクト層（API/型）を厳密に定義し、実装層は再生成可能に保つ
- 静的検査可能なルールはプロンプトではなく、その環境の linter か ast-grep で記述する
- 仕様や指示にないフォールバック実装は可能な限り避ける

## プランモード(/plan)

- 不明点は徹底的にユーザーにヒアリングして。曖昧な指示を許容しないで。

## 並列化と subagent

タスクを受けたら最初に「**並列化できる subtask は何か**」「**subagent に投げて main context を空けられるか**」を洗い出してから動く。default は subagent 優先 / 並列優先。

判断:

- 互いに独立な 2+ task → Agent tool で 1 message 内に並列 dispatch (independent search、 multi-scenario eval、 multi-model 比較など)
- 大量探索・grep・解析 (3+ query 規模) → general-purpose / Explore subagent に投げ、 main は要約だけ受け取る
- bias-free 評価 (skill / prompt / 自分の生成物の検証) → 新規 subagent。 「自分で再読」 は禁じ手 (empirical-prompt-tuning の caveat 通り)
- Long-running batch (Bash の 10 分上限を超える / apm install を多 repo に回す等) → subagent dispatch か run_in_background + Monitor

避けるべき:

- 直列依存 (前 task の結果が次 task 入力) を無理に並列化する
- 1-step / short lookup を subagent に投げる (overhead がコストに見合わない)
- subagent と main で同じ作業を二重で走らせる

## ツール

- タスク: justfile
- ローカルレビュー: /local-review skill を使用する (hunk セッションに subagent がレビューコメントを投稿する)
