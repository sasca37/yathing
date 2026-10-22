# 개발 문서

yathing을 직접 빌드하거나 코드를 살펴보려는 사람을 위한 문서입니다. 사용 방법은 [README](../README.md)를 보세요.

## 빌드와 실행

요구사항: macOS 13+, Xcode (Swift 5.9+)

```
./scripts/build-app.sh      # build/yathing.app 생성 (유니버설: Apple Silicon + Intel)
open build/yathing.app
```

- 서명은 Developer ID Application 인증서 → 이 Mac의 첫 코드서명 인증서 → ad-hoc 순으로 고릅니다. `SIGN_IDENTITY`로 지정할 수 있습니다.
- 서명이 빌드마다 바뀌면 권한(손쉬운 사용, 입력 모니터링)이 초기화되므로 인증서 서명을 권장합니다.
- 버전은 `VERSION=1.0.0`으로 지정합니다 (기본 0.1.0). 빌드 번호는 커밋 수입니다.

## 구조

```
Sources/MacForKeyset/
  App.swift               메뉴바 앱 진입점, 메뉴
  Store.swift             설정 상태, 권한 확인, 로그인 시 실행
  Config.swift            설정 모델(키보드 모드 포함)과 JSON 저장
  KeyEngine.swift         CGEventTap: 매핑, 단축키, 윈도우 단축키 변환, Alt+Tab, 이벤트 로깅
  HIDRemap.swift          hidutil 기반 modifier 매핑과 키보드 모드별 교환
  WindowsShortcuts.swift  "윈도우처럼" 모드의 단축키 변환 규칙 (설정 창 안내 표도 여기서 생성)
  InputSource.swift       입력 소스 전환
  WindowManager.swift     Accessibility 기반 창 분할
  EventLog*.swift         키 이벤트 뷰어
  SettingsView.swift      설정 창
  KeyNames.swift          keyCode ↔ 이름
scripts/build-app.sh      앱 번들 빌드와 서명
scripts/release.sh        배포용 DMG (서명, 공증, staple)
Resources/                앱 아이콘(원본 1024 PNG, .icns), 메뉴바 템플릿 아이콘(18pt/@2x)
```

## 동작 메모

- 설정 파일: `~/Library/Application Support/MacForKeyset/config.json`.
  번들 ID는 `com.sasca37.yathing`이고, 설정 폴더와 소스 타깃 이름은 예전 이름(MacForKeyset)을 그대로 씁니다.
- modifier 매핑과 키보드 모드는 `hidutil property --set`으로 적용되며 재부팅하면 사라집니다.
  앱 실행 때마다 다시 적용하고, 정상 종료하면 해제합니다. `hidutil`은 `UserKeyMapping` 전체를 덮어쓰므로 다른 도구의 hidutil 매핑과 충돌합니다.
- 키보드 모드는 hidutil 단계에서 modifier를 바꾸고(Ctrl→⌘ 등), 윈도우 단축키 변환은 그 뒤 이벤트 탭에서 처리합니다.
  그래서 `WindowsShortcuts`의 규칙은 교환된 뒤의 키 기준으로 적혀 있습니다.
- Alt+Tab은 Alt를 누르고 있는 동안 합성 ⌘를 눌러 두고, 그사이 들어오는 키의 ⌥ 플래그를 ⌘로 바꿉니다.
- 이벤트 탭, `hidutil`, 다른 앱 창 제어를 쓰기 때문에 샌드박스가 필요한 Mac App Store에는 올릴 수 없습니다.
  배포는 Developer ID 서명 + 공증 + DMG로 합니다 (`scripts/release.sh`).
- 자동 테스트는 없습니다. 이벤트 탭과 Accessibility는 권한이 필요한 시스템 동작이라 수동으로 확인합니다.
