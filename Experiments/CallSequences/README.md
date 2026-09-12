# 呼び出し反復の実験（終了）

#54の試作コードと常設CIは#57で撤去した。[公開OSS検証](../../docs/validation/oss-structural-context.md)では、本来の配置の問いに届かず、次は[既存構造との関係](../StructuralContext/README.md)を検証する。本番へ採用した機能ではない。

結果・限界は[検証記録](../../docs/validation/call-sequence-experiment.md)、判断は[0032](../../docs/decisions/0032-call-sequence-experiment.md)に残す。再現には固定した旧実装を作業ツリーと別のディレクトリへ展開する。

```sh
set -e
mkdir -p .build/archived-call-sequences
git archive --output=.build/archived-call-sequences/input.tar a172e609c2701806287c2b0111ab0b7e0f6a93e0 Experiments/CallSequences Fixtures/structural-reconsideration
tar -xf .build/archived-call-sequences/input.tar -C .build/archived-call-sequences
swift test --package-path .build/archived-call-sequences/Experiments/CallSequences --scratch-path .build/archived-call-sequences/build
python3 .build/archived-call-sequences/Experiments/CallSequences/verify.py --binary .build/archived-call-sequences/build/debug/call-sequence-probe --output .build/archived-call-sequences/result.json
```

展開先はこの用途だけに使う。対象アプリをビルド・実行する手順ではない。
