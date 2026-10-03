# soom

아이콘 하나에서 바탕화면 아이콘과 메뉴 막대를 관리하는 macOS 메뉴 막대 앱입니다.

## 사용법

- 메뉴 막대에는 **soom 고양이 아이콘 하나**만 표시됩니다.
- **아이콘 상태:** ‘전체 화면일 때만’에서는 고양이와 벽, ‘항상’에서는 고양이 없이 벽만 표시합니다.
- **기본 클릭:** 메뉴 막대 자동 가리기 ‘항상’ / ‘전체 화면일 때만’ 전환.
- **오른쪽 클릭 또는 Control-클릭:** 체크로 설정 변경.
  - ‘바탕화면 아이콘 표시’: 체크하면 표시, 해제하면 숨김.
  - 메뉴 막대 ‘항상’ / ‘전체 화면일 때만’: 원하는 항목을 선택하면 체크 이동.
  - 메뉴 막대 설정 다시 적용, 정보, 종료도 제공합니다.

두 메뉴 막대 모드 모두 전체 화면에서 자동으로 가려집니다. 메뉴 막대를 다시 보려면 포인터를 화면 맨 위로 옮기세요. 클릭 후 포인터를 아래로 옮겨야 다시 가려집니다.

앱 실행 시 기존 설정값을 변경하지 않고 메뉴 막대 정책을 다시 적용합니다. 종료 시 마지막으로 선택한 시스템 설정을 유지합니다. 다른 앱이나 시스템 설정에서 변경한 상태는 3초 간격으로 반영합니다.

## 빌드

Xcode에서 `soomsoom.xcodeproj`를 열고 `soomsoom` 스킴을 실행하세요. 기존 최소 지원 버전인 macOS 26.2를 유지합니다.

Xcode Command Line Tools만 설치된 Apple Silicon Mac에서는 다음과 같이 빌드할 수 있습니다.

```sh
./build.sh
# 원하는 출력 폴더 지정
./build.sh /absolute/path/to/output
```

결과물은 `build/soom.app`입니다. 스크립트 빌드는 로컬 임시 서명이며 Apple 공증 배포본은 아닙니다.

## 시스템 설정 적용

Finder의 `CreateDesktop` 설정을 저장하고 현재 사용자의 Finder를 다시 시작해 바탕화면 아이콘을 반영합니다. Finder 윈도우를 강제로 닫는 AppleScript는 제거했습니다.

메뉴 막대는 전역 `_HIHideMenuBar`와 `AppleMenuBarVisibleInFullscreen` 설정을 저장한 다음, 데스크탑 변경 알림과 `AppleInterfaceFullScreenMenuBarVisibilityChangedNotification`을 각각 전송합니다. 전체 화면 알림은 이미 열린 전체 화면의 메뉴 막대 정책을 다시 읽게 하는 데 필요합니다.

다른 앱의 설정과 전역 설정을 바꿔야 하므로 Xcode 타깃의 App Sandbox는 꺼져 있습니다. 접근성·화면 기록·Automation 권한을 사용하지 않습니다. macOS 내부 설정에 의존하므로 OS 업데이트에 따라 호환성 확인이 필요합니다.

참고: https://github.com/mgxv/houdini/blob/main/Sources/MenuBarToggler.swift
