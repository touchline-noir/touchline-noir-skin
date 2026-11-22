터치라인 누아르 스킨 업데이트 도구
TOUCHLINE NOIR SKIN UPDATER · Football Manager 27 · Windows Steam

이 도구는 FM27에 설치한 터치라인 누아르 스킨을 최신 공개 버전으로 바꿉니다.
스킨이 아직 없는 게임에 처음 설치할 때도 쓸 수 있습니다.

쓰는 방법
1. 이 폴더를 게임 폴더 밖(예: 바탕 화면, 문서)에 압축 해제합니다.
2. Update-TouchlineNoir.cmd 를 두 번 클릭합니다.
3. 새 버전이 있으면 바뀌는 스킨 파일 수, 내려받을 크기, 바뀐 점이 나옵니다. Y 를 누르면 진행합니다.
4. FM27이 켜져 있으면 게임을 끌 때까지 기다렸다가 계속합니다. (그만두려면 Ctrl+C)
5. 관리자 권한 확인 창(UAC)에서 "예"를 누르면 설치 창이 열리고, 끝나면 "업데이트 완료"가 나옵니다.
이미 최신이면 "이미 최신입니다"라고 알려 주고 아무것도 바꾸지 않습니다.
스킨 화면 파일은 그대로이고 설치 도구 · 문서만 바뀐 새 버전도 설치합니다(내려받는 양이 아주 적습니다).

하는 일
- GitHub(touchline-noir/touchline-noir-skin) 최신 릴리스의 업데이트 정보와 서명을 받아,
  도구 안에 들어 있는 공개 키로 확인합니다. 서명이 맞지 않거나, 전에 받은 것보다 오래된 정보면 멈춥니다.
- 마지막 설치 기록으로 테마(CLASSIC / LIGHT)를 알아내고, 설치된 스킨 파일과 비교해 바뀐 파일만 내려받습니다.
  받은 파일은 모두 SHA-256 값으로 확인합니다.
- 새 버전 설치 패키지를 %LOCALAPPDATA%\TouchlineNoir\packages 에 만들고, 설치 직전에 모든 파일을 다시 확인해
  설치가 끝날 때까지 바꿀 수 없게 잡아 둔 채 그 패키지의 설치 과정(2-Install.cmd와 같은 검사 · 원본 백업 ·
  설치 후 확인)으로 설치합니다.
- FM 원본 파일 백업은 지금처럼 게임 폴더의 NativeCalmBackup 에 그대로 둡니다.
- 게임 본체 · 외부 플러그인 · 사용자 글꼴 · 설정 · 세이브는 바꾸지 않습니다.
- 업데이트 도구 자체에 새 버전이 있으면 이 스크립트를 먼저 바꾸고 다시 시작합니다.

새 버전 알림 (선택)
- 업데이트를 마쳤거나 "이미 최신"일 때 한 번 물어봅니다. 켜 두면 로그인할 때와 3시간마다 업데이트 정보만
  확인하고, 새 버전이 있으면 Windows 알림을 띄웁니다. FM이 실행 중일 때는 알리지 않고,
  같은 버전은 사흘에 한 번만 다시 알립니다.
- 알림을 누르면 업데이트 도구가 열립니다. 설치는 지금처럼 Y 확인과 관리자 권한 확인을 거칩니다.
- 켜면 이 Windows 사용자 계정에만, 관리자 권한 없이 다음이 만들어집니다.
    작업 스케줄러 작업        TouchlineNoir Update Check
    알림 이름 등록            HKCU\Software\Classes\AppUserModelId\TouchlineNoir.SkinUpdater
    알림 클릭 연결            HKCU\Software\Classes\touchline-noir-update
    도구 사본 · 기록          %LOCALAPPDATA%\TouchlineNoir\tool, %LOCALAPPDATA%\TouchlineNoir\Logs\notify.log
- 켜기: Update-TouchlineNoir.cmd -Notify On
  끄기: Update-TouchlineNoir.cmd -Notify Off  (위 항목을 모두 지웁니다)

옵션 (명령 프롬프트에서 Update-TouchlineNoir.cmd 뒤에 붙입니다)
  -CheckOnly      새 버전이 있는지 확인만 합니다.
  -PrepareOnly    새 버전 설치 패키지를 받아 두기만 합니다. (그 폴더의 2-Install.cmd로 설치)
  -Theme LIGHT    테마를 고르거나 바꿉니다. (CLASSIC 또는 LIGHT)
  -GamePath "D:\SteamLibrary\steamapps\common\Football Manager 27"
                  게임 폴더를 직접 알려 줍니다.
  -Notify On      새 버전 알림을 켭니다.   -Notify Off  알림을 끕니다.
  예) Update-TouchlineNoir.cmd -Theme LIGHT

안전
- 공식 배포처는 GitHub의 touchline-noir/touchline-noir-skin 릴리스뿐입니다. 다른 곳에 올라온 스킨 · 업데이트 파일은
  실행하지 마세요. 스킨 설치 과정은 관리자 권한으로 실행됩니다.
- 서명 공개 키 지문(SHA-256, 모듈러스): d1472c957cdab4de3380982478e743dab8e1974219437087f20d8a2c9a85ba68
  (2026-11-22에 키를 바꿨습니다. 예전 업데이트 도구는 실행할 때 저절로 최신 업데이트 도구로 바뀝니다.)
- 실행 기록(%LOCALAPPDATA%\TouchlineNoir\Logs)에는 Windows 사용자 이름, PC 이름, 폴더 경로가 들어 있습니다.
  다른 사람에게 보내기 전에 확인하세요.

알아 둘 점
- Steam 빌드 26620374용입니다. FM27이 업데이트되어 빌드가 바뀌면 "아직 지원하지 않는 빌드"라고 알려 주고
  아무것도 바꾸지 않습니다. 그 빌드용 스킨이 나오면 다시 실행해 주세요.
- 원래 FM 화면으로 되돌리려면 설치 패키지 폴더의 3-Restore.cmd 를 씁니다.
  (업데이트 도구로 설치했다면 %LOCALAPPDATA%\TouchlineNoir\packages 의 해당 버전 폴더)
