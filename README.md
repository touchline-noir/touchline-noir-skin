# 터치라인 누아르 스킨 (TOUCHLINE NOIR SKIN)

Football Manager 27(Windows · Steam)용 비공식 스킨입니다. 어두운 **CLASSIC**과 밝은 **LIGHT** 두 테마가 있습니다.

## 내려받기

[최신 릴리스](https://github.com/touchline-noir/touchline-noir-skin/releases/latest)에서 받습니다.

| 파일 | 쓰임 |
| --- | --- |
| `TOUCHLINE-NOIR-SKIN-V…-WINDOWS.zip` | 스킨 전체 (두 테마, 설치 · 되돌리기 도구 포함) |
| `TOUCHLINE-NOIR-UPDATER.zip` | 업데이트 도구. 이미 설치한 스킨을 바뀐 파일만 받아 최신으로 바꿉니다 |

처음 설치: ZIP을 게임 폴더 밖에 압축 해제 → 원하는 테마 폴더의 `1-Check.cmd` → FM 완전 종료 → `2-Install.cmd`.
원래 화면으로 되돌리기: `3-Restore.cmd`.

## 업데이트

1. `TOUCHLINE-NOIR-UPDATER.zip`을 한 번 받아 게임 폴더 밖에 압축 해제합니다.
2. 새 버전이 나오면 `Update-TouchlineNoir.cmd`를 두 번 클릭합니다.
3. 바뀌는 파일과 내려받을 크기를 확인하고 `Y` → FM 종료 → 관리자 권한 확인 창에서 "예".

업데이트 도구는 다음 순서로 일합니다.

- 최신 릴리스의 `noir-update.json`과 서명(`noir-update.json.sig`, RSA-3072 · SHA-256)을 받아 도구 안의 공개 키로 확인합니다.
  서명이 맞지 않으면 아무것도 받지 않습니다.
- 게임 빌드(실행 파일 4개의 SHA-256)와 마지막 설치 기록의 테마를 확인하고, 설치된 스킨 파일과 비교해 바뀐 파일만 내려받습니다.
- 내려받은 파일과 게임 폴더에서 가져온 그대로인 파일로 새 버전 설치 패키지를 `%LOCALAPPDATA%\TouchlineNoir\packages`에 다시 만들고,
  그 패키지의 설치 과정(원본 백업 · 검사 · 설치 후 확인, 실패하면 되돌림)으로 설치합니다.

공개 키 지문 (모듈러스 SHA-256): `27809a0ba919ee91e830dad5300026965bd4f3850153b09bba80562ac19b722b`

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

## 권리 안내

비공식 스킨이며 게임 제작사와 공식 제휴를 뜻하지 않습니다. Football Manager, 게임 코드 · 자료 및 구단 · 대회 · 선수 관련 표식의
권리는 각 권리자에게 있습니다. 게임 이용에는 정당하게 보유한 지원 버전의 게임이 필요합니다.
자세한 내용과 출처는 스킨 ZIP의 `LICENSE-NOTICE-KO.txt`, `CREDITS-KO.txt`를 확인해 주세요.

스킨: TOUCHLINE NOIR / 초코깡통
