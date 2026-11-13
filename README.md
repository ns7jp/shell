# Bash・Python・PowerShellで学ぶサーバー構築運用案件パック

LinuxとWindowsの構築・点検・保守を、Bash・Python・PowerShellで学ぶ教材です。架空の依頼を題材に、コードと要件・設計・試験手順をまとめています。

> **更新停止（参考資料）**：2026-10-18 から教材の更新を停止しています。採用向けの主作品は [server](https://github.com/ns7jp/server) です。

## このリポジトリの位置づけ

AI支援で作成した文書・スクリプト・テストを含む学習用の副作品です。保存済みの実行記録はAI支援環境とCIが中心で、本人が自分の端末で実行したと確認できる記録はありません。[支援の履歴と主作品との関係](docs/learning-reference.md#このリポジトリの位置づけ)

<a id="30秒で分かる内容"></a>

## 代表的な教材

| 題材 | 確認できる内容 | 詳細 |
| --- | --- | --- |
| Linuxの点検と記録 | Bashで状態を点検し、PythonでログをJSONへ変換する設計 | [運用パック](docs/00-project-overview.md) |
| Nginxの構築と確認 | 設定の分離、ドライラン、構築後の受け入れ試験 | [構築パック](docs/11-build-project-overview.md) |
| Windowsの構築・運用 | PowerShellでIISの構築・点検を扱い、Linux版とログ書式を共有する教材 | [PowerShellパック](docs/20-powershell-project-overview.md) |

## 現在の検証範囲

[検証証跡](docs/08-evidence.md)には、自己完結テスト、CI、コンテナでのNginx導入などの結果を記録しています。実Ubuntu VMでの構築・再起動後の確認、実WindowsでのIIS構築、本人によるBash演習21問の完走は **未実施（NOT RUN）** です。Git for Windowsの初期記録は実行者の確認待ちです。

## 教材を読む・試す

- **最初の演習**：[Bash演習21問](exercises/README.md)
- **教材を選ぶ**：[全6パック・スクリプト一覧・学習ルート](docs/learning-reference.md)
- **動かして確かめる**：[Linux / PowerShellの操作例](docs/learning-reference.md#最短5分の体験)

学習用の隔離した検証環境で試してください。変更を伴うスクリプトは既定でドライランです。実行条件・終了コード・注意点は操作例と各ハンズオンに記載しています。

<details>
<summary>以前のREADMEの節から探す</summary>

<a id="powershell演習パックのスクリプト"></a><a id="学べること"></a><a id="最短5分の体験"></a><a id="powershell演習パックを試す"></a><a id="学習ルート"></a><a id="ディレクトリ構成"></a><a id="評価しやすいポイント"></a>

スクリプト一覧、操作例、学習ルート、ディレクトリ構成、設計上の工夫は[教材・操作手順・学習ルート](docs/learning-reference.md)へ移しました。

</details>

## ライセンス

[MIT License](LICENSE)
