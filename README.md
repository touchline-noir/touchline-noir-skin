# 터치라인 누아르 스킨 (TOUCHLINE NOIR SKIN)

Football Manager 27(Windows · Steam)용 비공식 스킨입니다. 어두운 **CLASSIC**과 밝은 **LIGHT** 두 테마가 있습니다.
V6부터는 BepInEx를 쓰는 분을 위한 선택 플러그인 두 가지(여행 장면 · 게임 안 업데이트 알림)도 함께 들어 있습니다.

## 내려받기

[최신 릴리스](https://github.com/touchline-noir/touchline-noir-skin/releases/latest)에서 받습니다.

| 파일 | 쓰임 |
| --- | --- |
| `TOUCHLINE-NOIR-SKIN-V…-WINDOWS.zip` | 스킨 전체 (두 테마, 설치 · 되돌리기 · 업데이트 도구 포함). V6부터 `PLUGINS` 폴더(선택 플러그인)도 들어 있습니다 |
| `TOUCHLINE-NOIR-SKIN-V…-STADIUMS.zip` | 여행 장면 플러그인의 경기장 그림(약 2GB). 플러그인을 쓸 때만 받아 본체 ZIP과 같은 폴더에 풉니다 |
| `TOUCHLINE-NOIR-UPDATER.zip` | 업데이트 도구. 이미 설치한 스킨을 바뀐 파일만 받아 최신으로 바꿉니다 |

처음 설치: ZIP을 게임 폴더 밖에 압축 해제 → 원하는 테마 폴더의 `1-Check.cmd` → FM 완전 종료 → `2-Install.cmd`.
원래 화면으로 되돌리기: `3-Restore.cmd`.

## BepInEx 플러그인 (선택, V6부터)

FM27에 BepInEx 6 (IL2CPP)를 이미 쓰는 분만 설치할 수 있습니다. 플러그인 설치 도구는 BepInEx를 설치하지 않으며,
스킨은 플러그인 없이도 그대로 동작합니다.

- 여행 장면(`TouchlineNoir.Travel`): 경기 로딩 화면에 원정 이동 지도 → 도착 → AI 경기장 공개, 홈 경기에는 상대 팀이
  원정 오는 장면과 이동 소리. 누아르 스킨이 설치된 게임 빌드에서만 켜집니다.
- 게임 안 업데이트 알림(`TouchlineNoir.UpdateNotice`): 새 버전이 나오면 게임 안 알림 카드와 '업데이트하기' 버튼.

설치: 두 ZIP을 게임 폴더 밖의 같은 새 폴더에 풀고 스킨을 먼저 설치 → FM 완전 종료 → `PLUGINS\1-Check-Plugins.cmd`
→ `PLUGINS\2-Install-Plugins.cmd`. 제거: `PLUGINS\3-Remove-Plugins.cmd`.
업데이트 도구는 플러그인을 설치하거나 바꾸지 않습니다(새 플러그인은 릴리스 ZIP으로 받습니다).

## 업데이트

1. `TOUCHLINE-NOIR-UPDATER.zip`을 한 번 받아 게임 폴더 밖에 압축 해제합니다.
2. 새 버전이 나오면 `Update-TouchlineNoir.cmd`를 두 번 클릭합니다.
3. 바뀌는 파일과 내려받을 크기를 확인하고 `Y` → FM 종료 → 관리자 권한 확인 창에서 "예".

게임 안 업데이트 알림 플러그인을 쓰면 알림 카드의 '업데이트하기'로도 업데이트합니다(업데이트 도구 v5부터,
`Update-TouchlineNoir.cmd`를 한 번 실행해 둔 뒤). 누르면 새 버전을 받아 두고, FM을 끄면 바로 설치합니다.

업데이트 도구는 다음 순서로 일합니다.

- 최신 릴리스의 `noir-update.json`과 서명 목록(`noir-update.json.sigs`, RSA-3072 · SHA-256)을 받아 도구 안의 공개 키로 확인합니다.
  서명이 맞지 않거나 전에 받은 것보다 오래된 정보면 아무것도 받지 않습니다.
- 게임 빌드(실행 파일 4개의 SHA-256)와 마지막 설치 기록의 테마를 확인하고, 설치된 스킨 파일과 비교해 바뀐 파일만 내려받습니다.
- 내려받은 파일과 게임 폴더에서 가져온 그대로인 파일로 새 버전 설치 패키지를 `%LOCALAPPDATA%\TouchlineNoir\packages`에 다시 만들고,
  설치 직전에 모든 파일을 다시 확인해 설치가 끝날 때까지 바꿀 수 없게 잡아 둔 채, 그 패키지의 설치 과정
  (원본 백업 · 검사 · 설치 후 확인, 실패하면 되돌림)으로 설치합니다.
- 확인한 업데이트 정보(서명 포함)를 `%LOCALAPPDATA%\TouchlineNoir\latest`에 저장하고, 알림 플러그인이 설치돼 있으면
  그 플러그인 폴더에도 저장합니다(플러그인이 서명을 다시 확인하고, FM은 인터넷에 접속하지 않습니다).

공개 키 지문 (모듈러스 SHA-256): `d1472c957cdab4de3380982478e743dab8e1974219437087f20d8a2c9a85ba68`
(2026-11-22 키 교체. 예전 업데이트 도구는 예전 키 서명 `noir-update.json.sig`로 최신 업데이트 도구까지 저절로 바뀝니다.)
스킨 화면 파일이 그대로이고 설치 도구 · 문서만 바뀐 새 버전도 설치합니다(업데이트 도구 v4부터).

### 안전

- 공식 배포처는 이 저장소의 GitHub 릴리스뿐입니다. 다른 곳에 올라온 스킨 · 업데이트 파일은 실행하지 마세요.
- V5.0.2부터 설치 도구는 게임 폴더의 `NativeCalmBackup`(원본 백업)을 관리자만 고칠 수 있게 바꾸고, 그 안에 설치 도구가 만들지 않은 링크가 있으면 아무것도 바꾸지 않고 멈춥니다.
- 실행 기록(`%LOCALAPPDATA%\TouchlineNoir\Logs`)에는 Windows 사용자 이름 · PC 이름 · 폴더 경로가 들어 있습니다. 공유하기 전에 확인하세요.

### 새 버전 알림 (선택)

업데이트를 마쳤거나 "이미 최신"일 때 업데이트 도구가 한 번 물어봅니다. 켜 두면 로그인할 때와 3시간마다 업데이트 정보만 확인하고,
새 버전이 있으면 Windows 알림을 띄웁니다(FM 실행 중에는 알리지 않음, 같은 버전은 사흘에 한 번). 알림을 누르면 업데이트 도구가 열립니다.
이 Windows 사용자 계정에만 작업 스케줄러 작업(`TouchlineNoir Update Check`)과 알림 등록이 생기며,
`Update-TouchlineNoir.cmd -Notify Off`로 모두 지울 수 있습니다.

## 지원

- Football Manager 27 · Windows x64 · Steam 빌드 26620374
- Game Pass · macOS · 다른 게임 빌드는 지원하지 않습니다. FM27이 업데이트되면 그 빌드용 스킨이 나올 때까지
  업데이트 도구는 아무것도 바꾸지 않습니다.
- 추천 화면 비율 16:9, 정보 표시 크기는 2560×1440 · 1920×1080에서 '보통', 4K에서 '보통' 또는 '작게'.
- 플러그인: BepInEx 6.0.0-be.791 (IL2CPP)에서 만들고 확인했습니다. 여행 장면의 지도는 유럽 · 영국 · 이탈리아만 있습니다.

## 권리 안내

비공식 스킨이며 게임 제작사와 공식 제휴를 뜻하지 않습니다. Football Manager, 게임 코드 · 자료 및 구단 · 대회 · 선수 관련 표식의
권리는 각 권리자에게 있습니다. 게임 이용에는 정당하게 보유한 지원 버전의 게임이 필요합니다.
자세한 내용과 출처는 스킨 ZIP의 `LICENSE-NOTICE-KO.txt`, `CREDITS-KO.txt`를 확인해 주세요.

스킨: TOUCHLINE NOIR / 초코깡통
