# yathing

윈도우 키보드를 맥에서 편하게 쓰게 해 주는 macOS 메뉴바 앱입니다.
메뉴에서 한 번 고르면 Ctrl+C 복사, Alt+Tab 앱 전환, 한/영 키 전환을 윈도우처럼 쓸 수 있습니다.
키 매핑(우측 ⌘ 한영 전환)과 단축키 창 분할도 제공합니다.

## 설치

1. [Releases](https://github.com/sasca37/yathing/releases/latest)에서 `yathing-<버전>.dmg`를 받습니다.
2. DMG를 열고 `yathing`을 `Applications` 폴더로 끌어다 놓습니다.
3. 응용 프로그램에서 yathing을 실행하고, 아래 [권한](#권한) 두 가지를 허용한 뒤 앱을 다시 실행합니다.
4. 메뉴바의 yathing 아이콘 → 키보드 모드를 고릅니다.

요구사항: macOS 13 이상 (Apple Silicon, Intel 모두 지원)

키 입력은 이 Mac 안에서만 처리하며, 디스크에 저장하거나 네트워크로 보내지 않습니다. 소스 코드는 이 저장소에 모두 공개되어 있습니다.

## 기능

- **한영 전환**: 우측 ⌘ → F15 로 바꾸고, 시스템 설정의 '이전 입력 소스 선택'에 F15를 지정해서 사용합니다.
  F15가 먹지 않으면 매핑 대상을 "입력 소스 전환"으로 바꾸면 앱이 직접 전환합니다.
- **키 매핑**: 임의의 키를 F13–F20 또는 입력 소스 전환으로 매핑합니다.
  modifier 키(⌘⌥⌃⇧ 등) 매핑은 `hidutil`(HID 드라이버 단계)로 적용해 시스템 전체에서 원래 키처럼 동작하지 않습니다.
- **창 분할**: 좌·우·상·하 절반, 최대화. 단축키는 설정에서 녹화해서 바꿉니다. 기본값은 ⌃⌥+방향키, ⌃⌥+Return.
- **키 이벤트 뷰어**: keyCode(10/16진수), 키 이름, 입력 문자, modifier, 현재 눌린 키를 실시간으로 보여줍니다.
  "원본 키 보기"를 켜면 매핑을 잠시 풀고 물리 키 값을 확인할 수 있습니다.
- **키보드 모드**: 메뉴바나 설정 창에서 셋 중 하나를 고릅니다.
  - 맥 키보드: 키를 바꾸지 않습니다.
  - 윈도우 키보드 · 맥처럼: Alt 자리가 ⌘, Win 자리가 ⌥가 되어 맥 키보드와 같은 배열로 씁니다.
  - 윈도우 키보드 · 윈도우처럼 (초보자용): Ctrl이 ⌘, Win이 ⌃가 되어 Ctrl+C/V 같은 윈도우 단축키를 그대로 씁니다.
    Alt+Tab(앱 전환), Ctrl+Tab(브라우저 탭), Home/End, Ctrl+←/→, Ctrl+Backspace, Alt+F4, Print Screen, Ctrl+Shift+Esc, Win+E/D/L, Win+←/→/↑도 맥 동작으로 바꿉니다.
    전체 목록은 설정 창의 "이렇게 동작해요"에 있습니다 (`WindowsShortcuts.swift`의 규칙 표에서 만들어집니다).
  - 윈도우 키보드 모드에서는 오른쪽 Alt(한/영 키)가 우측 ⌘ 매핑을 따라가서 한영 전환이 됩니다.
- **로그인 시 자동 실행**: 설정 창에서 켭니다. 앱을 `/Applications`로 옮긴 뒤 켜세요.

## 빌드와 실행

요구사항: macOS 13+, Xcode(Swift 5.9+)

```
./scripts/build-app.sh      # build/yathing.app 생성
open build/yathing.app
```

서명은 Developer ID Application 인증서 → 이 Mac의 첫 코드서명 인증서 → ad-hoc 순으로 고릅니다. `SIGN_IDENTITY`로 지정할 수 있습니다.
서명이 빌드마다 바뀌면 권한이 초기화되므로 인증서 서명을 권장합니다. 버전은 `VERSION=1.0.0`으로 지정합니다(기본 0.1.0).

## 권한

시스템 설정 → 개인정보 보호 및 보안에서 아래 **두 가지 모두** 허용해야 합니다.

1. 손쉬운 사용 (키 이벤트 가로채기, 창 제어)
2. 입력 모니터링 (키 이벤트 수신)

설정 창(메뉴바 → 설정…)에서 각 권한과 "키 처리 엔진" 상태를 확인할 수 있습니다.

문제 해결:
- 허용했는데 "필요"로 남으면, 목록에서 항목을 삭제(−)하고 앱을 재실행해 다시 허용하세요.
  이전 서명으로 등록된 무효 항목일 수 있습니다. 터미널에서는 `tccutil reset Accessibility com.sasca37.yathing`.
- 권한을 바꾼 뒤에는 앱을 종료하고 다시 실행하세요.

## 설정과 동작 참고

- 설정 파일: `~/Library/Application Support/MacForKeyset/config.json`
- 번들 ID는 `com.sasca37.yathing`입니다. 설정 폴더와 소스 타깃 이름은 예전 이름(MacForKeyset)을 그대로 씁니다.
- modifier 매핑은 `hidutil property --set`으로 적용되며 재부팅하면 사라집니다. 앱 실행 때마다 다시 적용하고, 종료하면 해제합니다.
  `hidutil`은 `UserKeyMapping` 전체를 덮어쓰므로 다른 도구의 hidutil 매핑과 충돌합니다.
- 키 이벤트는 이벤트 뷰어 창이 열려 있을 때만 메모리에 기록하고(최대 300개), 디스크나 네트워크로 보내지 않습니다.
- 이벤트 탭, `hidutil`, 다른 앱 창 제어를 사용하므로 샌드박스가 필요한 Mac App Store 배포는 어렵습니다. 배포는 Developer ID 서명 + 공증 + DMG 기준입니다.

## 알려진 한계

- 대상이 "입력 소스 전환"인 매핑은 이벤트 탭 방식이라, 우측 ⌘를 누른 채 클릭하면 여전히 ⌘ 클릭으로 처리됩니다.
- 윈도우 키보드 모드는 `hidutil`로 적용되어 연결된 모든 키보드(내장 키보드 포함)에 같이 적용됩니다.
  맥 키보드를 쓸 때는 "맥 키보드"로 바꾸세요.
- "윈도우처럼" 모드의 한계: Ctrl이 ⌘가 되므로 터미널의 Ctrl+C(중지)는 복사가 되고, Ctrl+클릭은 ⌘클릭이 됩니다.
  Win+D는 시스템 기본 단축키(F11)를 보내므로
  바탕화면 보기 단축키를 바꿨다면 동작하지 않습니다.
- Caps Lock은 modifier 처리 방식이 달라 매핑 대상으로 불확실합니다.
- 자동 테스트는 없습니다. 이벤트 탭과 Accessibility는 권한이 필요한 시스템 동작이라 수동으로 확인합니다.

## 배포 (관리자용)

공증된 DMG를 만들어 GitHub Releases에 올립니다.

처음 한 번 준비:
1. [Apple Developer Program](https://developer.apple.com/programs/) 가입 (연 $99).
2. Xcode → Settings → Accounts → Manage Certificates → `+` → **Developer ID Application** 인증서 생성.
   `security find-identity -v -p codesigning`에 `Developer ID Application: ...`이 보이면 됩니다.
3. [appleid.apple.com](https://appleid.apple.com)에서 앱 암호를 만들고, 공증 자격 증명을 키체인에 저장합니다.
   ```
   xcrun notarytool store-credentials yathing-notary --apple-id <Apple ID 이메일> --team-id <팀 ID>
   ```

릴리스할 때마다:
```
VERSION=1.0.0 ./scripts/release.sh   # 빌드 → DMG → 서명 → 공증 → staple, 마지막에 sha256 출력
git tag v1.0.0 && git push origin main --tags
```
GitHub → Releases → Draft a new release에서 태그 `v1.0.0`을 고르고 `build/yathing-1.0.0.dmg`를 첨부합니다.
출력된 sha256은 Homebrew cask에 씁니다.

## 라이선스

[MIT](LICENSE)

## 구조

```
Sources/MacForKeyset/
  App.swift            메뉴바 앱 진입점
  Store.swift          설정 상태, 권한 확인, 로그인 시 실행
  Config.swift         설정 모델과 JSON 저장
  KeyEngine.swift      CGEventTap: 매핑, 단축키, 이벤트 로깅
  HIDRemap.swift       hidutil 기반 modifier 매핑
  InputSource.swift    입력 소스 전환
  WindowsShortcuts.swift  "윈도우처럼" 모드의 단축키 변환 규칙
  WindowManager.swift  Accessibility 기반 창 분할
  EventLog*.swift      이벤트 뷰어
  SettingsView.swift   설정 창
  KeyNames.swift       keyCode ↔ 이름
scripts/build-app.sh   앱 번들 빌드와 서명
scripts/release.sh     배포용 DMG (서명, 공증, staple)
Resources/AppIcon.*    앱 아이콘 (원본 1024 PNG와 빌드에 쓰는 .icns)
Resources/MenuBarIcon* 메뉴바 아이콘 (템플릿 이미지, 18pt/@2x)
```
