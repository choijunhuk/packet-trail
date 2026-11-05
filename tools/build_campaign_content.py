#!/usr/bin/env python3
"""Build authored campaign data and test-only solution fixtures. No dependencies."""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot/data/campaign"
LOCALES = {"ko": {}, "en": {}}


def loc(key, ko, en):
    assert key not in LOCALES["ko"], key
    LOCALES["ko"][key] = ko
    LOCALES["en"][key] = en
    return key


# Story text is authored here; canonical puzzle bytes, addresses and IDs are stable.
# id, chapter, title ko/en, sender, brief ko/en, reply ko/en, host, target summary.
STORIES = [
    ("M01", 1, "첫 번째 야간 의뢰", "The First Night Job", "C01",
     "이 메일은 한 번만 보낼게요. 야간 보관소에서 인계 기록 N47이 곧 정리됩니다. 원본을 없애지 말고 사본 하나만 ~/archive에 남겨 주세요.\n\n공개 접속은 guest / guest입니다. 보호 폴더가 닫혀 있으면, 남아 있는 인수인계 메모를 읽어 보세요. 직접 들어가는 길과 보관 사본을 찾는 길 중 무엇을 택할지는 당신 몫입니다.",
     "I will send this only once. Handoff record N47 is due for removal from the night archive. Leave the original intact and keep one copy in ~/archive.\n\nPublic access is guest / guest. If the protected folder is closed, read the shift note that remains. You can enter the archive or find a cached copy. The route is yours.",
     "받았어요. 원본도 남아 있군요. 그런데 이 기록에는 송신 한 건이 빠졌습니다. 릴레이 02가 목적지를 바꾼 시각, 00:47을 기억해 주세요. 다음 주소를 보냈습니다.",
     "Received. The original is still there. But one transmission is missing from this handoff. Remember when relay 02 changed destination: 00:47. I have sent the next address.",
     "archive", "N47 handoff: relay-02 -> archive-17 at 00:47"),
    ("M02", 1, "기록이 가리킨 뒷문", "The Door in the Log", "C02",
     "서윤이 자료를 넘겼어요. 저는 야간망을 맡았던 도윤입니다. N47 옆에는 실패 표시가 없는데 왜 누락이라고 했을까요? 로그를 이름 순서대로 읽으면 중요한 줄을 놓칩니다.\n\n현재 로그와 회전된 로그, 배포 메모가 같은 작업 번호를 말하는지 확인해 주세요. 서버를 고치는 의뢰가 아닙니다. 누가 어느 목적지로 보냈는지부터 알아야 합니다.",
     "Seoyun passed me your copy. I am Doyun, formerly on the night network. N47 is not marked failed, so why is a transmission missing? Reading files alphabetically can hide the important line.\n\nCompare the current log, rotated log and deployment note by job ID. This is not a repair job. First find who sent what, and where.",
     "연결은 끊기지 않았어요. 목적지가 relay-02에서 transit-04로 바뀌었고 예외 항목만 빠졌습니다. 제가 알던 장애 설명과 다르군요. 그 서버가 정말 꺼졌는지 확인하죠.",
     "The link never went down. Its destination changed from relay-02 to transit-04, and only exception entries disappeared. That is not the outage I was told about. Let us see whether that server is really offline.",
     "relay02", "job N47 changed destination under request R204"),
    ("M03", 1, "살아 있는 포트", "A Port Still Listening", "C01",
     "transit-04는 폐기됐다고 되어 있습니다. 하지만 인계표는 그곳을 지나갔어요. 접속 주소만 믿고 같은 문을 계속 두드리지 마세요. 살아 있는 서비스와 닫힌 문은 다릅니다.\n\n도윤이 NetProbe를 연결했습니다. 포트가 보인다는 사실이 권한을 준다는 뜻은 아닙니다. 어떤 서비스인지 알아낸 다음, 제한된 점검 세션으로 들어가 표식을 확인해 주세요.",
     "transit-04 is listed as retired, but the handoff passed through it. Do not keep knocking on the same assumed address. A listening service and a closed door are different.\n\nDoyun connected NetProbe. Seeing a port does not grant access. Identify the service, enter a limited inspection session, and verify its marker.",
     "폐기된 것은 시민용 화면뿐이었군요. 정비 서비스는 살아 있고 R204가 남아 있습니다. 다음 기록은 도서관 예약 서버에서 조회됐어요. 누군가 남은 시스템을 길로 쓰고 있습니다.",
     "Only the public page was retired. The maintenance service is alive and still holds R204. The next record was queried through the library reservation server. Someone is using the systems left behind as a route.",
     "transit04", "maintenance service on transit-04 still serves marker R204"),
    ("M04", 1, "같은 주소, 다른 대답", "One Address, Two Answers", "C02",
     "예약 화면에는 만남이 취소됐다고 나옵니다. 그런데 서버의 응답은 다른 기록을 가리켜요. 화면을 새로 고치는 것으로는 어느 쪽이 맞는지 알 수 없습니다.\n\nRequestLab에서 조회 요청과 응답의 참조를 나란히 보세요. 시민 예약을 새로 만들거나 취소할 필요는 없습니다. 사라진 변경 기록 한 건만 찾아 주세요.",
     "The reservation page says a meeting was cancelled, yet the server response points to another record. Refreshing the screen cannot tell us which is right.\n\nUse RequestLab to compare a lookup and its response reference. You do not need to create or cancel a citizen booking. Find the missing amendment only.",
     "화면의 취소와 서버의 이관은 같은 일이 아니었습니다. 접수증 C731이 수리 포털로 넘어갔군요. 서린에게 연락해 보겠습니다. 여기서부터는 자료의 주인이 중요해집니다.",
     "A cancellation on screen and a transfer on the server were not the same event. Receipt C731 moved into the repair portal. I will contact Serin. From here, ownership matters.",
     "library", "reservation amendment R204 links receipt C731"),
    ("M05", 2, "남의 수리 접수증", "Someone Else's Receipt", "C01",
     "서린의 접수증은 본인 수리 내역 대신 분실된 정비 보고서를 참조합니다. 화면의 버튼이 없어도 서버가 자료를 줄 수 있을까요? 자기 접수증을 기준으로 차이를 확인해 주세요.\n\n이번 의뢰의 대상은 C731의 허구 보고서뿐입니다. 객체 참조를 확인해도 되고 변경 이력의 사본을 찾아도 됩니다. 다른 시민 자료를 모으는 것이 성공은 아닙니다.",
     "Serin's receipt points to a missing maintenance report instead of her repair. Could the server still return it when the page has no button? Use her own receipt as a baseline.\n\nOnly the fictional C731 report is in scope. Inspect its object reference or follow a copy in the amendment history. Collecting unrelated citizen data is not success.",
     "보고서의 주인은 서비스 화면이 정해 주지 않았습니다. C731의 원본에는 ‘예외 보류’가 있었고 사본에서는 지워졌어요. 접근 결함과 기록 삭제는 다른 문제입니다. 로그인 서버가 갑자기 시끄러워졌군요.",
     "The service page did not determine the report's owner. The C731 original said 'exception hold'; its copy omitted that line. The access flaw and the missing record are separate problems. The login server has just become noisy.",
     "repair", "receipt C731 exposes exception-hold amendment"),
    ("M06", 2, "열 번의 문 두드림", "Ten Knocks at the Door", "C02",
     "누군가 야간 계정에 반복 로그인하면서 정상 정비사도 들어가지 못합니다. 다 잠그면 공격도 멈추겠지만, 병원 알림 작업도 멈춰요. 이번에는 경로를 찾는 것만으로 끝나지 않습니다.\n\n실패 기록을 비교하고, 반복 시도를 제한하면서 정비사의 정상 로그인은 살려 주세요. 가상 시계는 필요할 때만 진행합니다. 기다리는 시간을 실력으로 평가하지 않겠습니다.",
     "Repeated login attempts are locking out real maintenance staff. Locking everybody out would stop the attempts, but also the hospital notification job. This time finding a route is not enough.\n\nCompare failures and limit repeated attempts while preserving legitimate sign-in. Advance the simulated clock only when needed. Waiting is not a measure of skill.",
     "정상 작업은 다시 시작됐고 반복 실패는 제한됩니다. 로그의 요청 표식은 외부 침입이 아니라 오래된 복구 작업과 겹쳤어요. 누가 그 작업의 세션을 남겼는지 봐야겠습니다.",
     "Normal work is running again and repeated failures are limited. The request marker overlaps an old recovery job rather than an unknown intruder. Now we need to see whose session that job retained.",
     "auth", "throttle repeated attempts while preserving staff login"),
    ("M07", 2, "로그아웃한 사람의 열쇠", "The Key After Logout", "C02",
     "임시 정비사는 퇴근했고 화면도 로그아웃 상태입니다. 그런데 그 사람의 예전 세션으로 설정 변경이 계속돼요. 화면에서 없어진 열쇠가 서버에서도 사라졌다고 볼 수 있을까요?\n\n오래된 세션과 새 세션을 분리해 확인하세요. 모두 지우기보다 누가 아직 무엇을 할 수 있는지 확인하고, 끝난 권한만 끝내야 합니다.",
     "The temporary technician has left and the page shows a logout. Yet configuration changes continue through the old session. Does a key disappearing from the screen mean the server revoked it?\n\nCompare the old and new sessions separately. Instead of erasing everything, determine who can still do what, then end only the expired authority.",
     "예전 세션은 끝났고 새 정비 세션은 정상입니다. 마지막 변경은 로그인 직후가 아니라 외부 공지를 본 뒤에 생겼군요. 열쇠를 가진 사람이 직접 문을 연 것은 아닐 수 있습니다.",
     "The old session is invalid and the new maintenance session works. The final change followed an external notice, not a new sign-in. Having a key may not mean its owner chose to open the door.",
     "session", "revoke stale session and retain fresh authenticated work"),
    ("M08", 2, "클릭한 적 없는 변경", "The Change Nobody Clicked", "C01",
     "서린은 알림 주소를 바꾸지 않았다고 합니다. 세션 기록은 맞는데 의도는 맞지 않아요. 공지 열람과 설정 변경의 맥락을 비교해 주세요.\n\n사용자의 키가 붙어 온다는 이유만으로 모든 변경을 받아서는 안 됩니다. 유도된 변경을 막으면서 정상 설정 저장은 남겨 주세요. 이 장의 기록을 연결하면 검색 서버의 숨은 항목이 보일 겁니다.",
     "Serin says she never changed her notification address. The session is real; the intent is not. Compare the context of reading the notice and changing a setting.\n\nA user's key arriving with a request does not make every change intentional. Block the induced change and preserve normal saves. Connecting this chapter's records will point to a hidden search entry.",
     "정상 저장은 되고 의도 없는 변경은 막혔습니다. 설정 변경 요청이 검색 색인의 누락을 덮는 데 쓰였군요. 처음 보는 연락처가 원자료를 요구했습니다. 저를 믿으라는 말 대신 자료를 보내겠습니다.",
     "Normal saves work and the induced change is blocked. That request was masking a missing search entry. A new contact has asked for the original evidence. I will send the evidence instead of asking for trust.",
     "subscription", "reject induced cross-origin change and preserve legitimate save"),
    ("M09", 3, "검색창 뒤의 쿼리", "Behind the Search Box", "C03",
     "당신들이 가진 것은 같은 보고서의 서로 다른 사본입니다. 저는 민서라고 불러 주세요. 화면에 없는 기록을 추측하는 대신 어떤 입력이 어떤 조회 구조가 되는지 확인합시다.\n\n작은 검색 모형과 정비 로그에는 같은 작업의 흔적이 남았습니다. 어느 길로든 원본 작업 R609와 C731의 연결을 입증해 주세요. 결과가 많이 나오는 것과 필요한 사실을 찾는 것은 다릅니다.",
     "You have different copies of the same report. Call me Minseo. Instead of guessing at an unseen record, inspect how input becomes a query structure.\n\nThe small search model and maintenance log retain traces of the same job. Either route can establish how R609 connects to C731. Returning more rows is not the same as finding the fact we need.",
     "R609는 실패가 아니라 ‘분류 제외’였습니다. 누락을 단순 장애라고 부르면 피해자가 없어지는군요. 다음 표식은 공지 원문과 화면 사이에 있습니다. 출력된 모습만 믿지 마세요.",
     "R609 was not a failure; it was excluded by classification. Calling that an outage makes the affected people disappear. The next marker sits between a notice's source and its display. Do not trust appearance alone.",
     "records", "query record R609 links receipt C731 to exclusion queue"),
    ("M10", 3, "공지에 섞인 행동", "An Action Inside a Notice", "C03",
     "공지 원문은 ‘접수 보류’인데 화면에는 ‘수리 완료’가 떠요. 격리된 검증 창을 준비했습니다. 시민 화면을 바꾸지 말고 그 창에서만 입력이 어디까지 행동으로 해석되는지 보세요.\n\n자료를 안전하게 저장했다는 말과 화면에 안전하게 표시했다는 말은 다릅니다. 실행 표식이나 독립적인 표시 추적 자료 중 어느 쪽으로 경계를 입증해도 됩니다.",
     "The source notice says 'receipt on hold', while the display says 'repair complete'. I prepared an isolated inspection window. Leave citizen pages untouched and see where input becomes action only in that window.\n\nSafe storage and safe display are different claims. Demonstrate the boundary with the marker effect or an independent render trace.",
     "내용과 행동이 섞인 지점을 찾았습니다. 이것이 모든 잘못된 공지의 원인이라는 뜻은 아닙니다. 파일 서버의 보관 경로도 확인해야 해요. 자료실 옆에 이름이 비슷한 다른 폴더가 있습니다.",
     "We found where content became action. That does not explain every incorrect notice. Check the file archive too. There is another directory beside the public collection with a deceptively similar name.",
     "bulletin", "untrusted notice marker crosses the isolated render boundary"),
    ("M11", 3, "자료실 바깥의 파일", "Beyond the Archive Folder", "C01",
     "자료실 담당자는 접두 경로를 검사했으니 안전하다고 합니다. 하지만 첨부 참조가 이웃 보관 폴더를 가리켜요. 실제 경로로 해석한 뒤에도 같은 경계 안에 있는지 확인해 주세요.\n\n필요한 것은 경계를 증명할 표식 파일 하나입니다. 다른 설정이나 시민 자료를 가져올 이유는 없습니다. 파일 담당자의 감사 경로도 열려 있습니다.",
     "The archivist says checking a path prefix makes the archive safe. Yet an attachment reference points into a neighboring store. Check the boundary after the path is resolved.\n\nWe need one marker file to demonstrate the boundary, not other configuration or citizen records. The file auditor's route is available too.",
     "이름의 시작과 실제 위치는 달랐군요. 표식에는 업로드 처리 큐가 남아 있습니다. 서윤이라는 이름도 그 승인표에 있어요. 제가 직접 설명할 차례가 가까워졌네요.",
     "A shared name prefix did not mean a shared location. The marker names an upload-processing queue. Seoyun also appears on its approval sheet. It is almost time for me to explain that signature.",
     "files", "resolved attachment path reaches the adjacent marker file"),
    ("M12", 3, "사진이라는 이름의 파일", "A File Called a Photograph", "C02",
     "사진을 올리면 가상 처리 작업이 실행됩니다. 확장자만 바꾸는 것으로 막으면 정상 사진도 잃어요. 이름, 내용 형식, 저장 위치, 실행 경로를 따로 봅시다.\n\n정상 정비 사진을 계속 받고 잘못된 처리 경로만 막아 주세요. 끝나면 서윤이 직접 통화하겠다고 합니다. 그 사람의 얼굴을 볼지는 당신이 선택해도 사건은 계속됩니다.",
     "Uploading a photograph starts a virtual processing job. Blocking extensions alone can also lose real photos. Separate the name, content type, storage location and execution path.\n\nKeep maintenance photos working while closing the incorrect processing route. Seoyun wants to call afterward. Choosing whether to reveal her portrait will not gate the case.",
     "사진은 들어오고 실행 경계는 지켜집니다. 서윤입니다. 저는 이관 도구를 만들었지만 분류 제외까지 승인하지 않았어요. 제 서명만으로 결론 내리지 말고 진단 서버의 실제 작업을 봐 주세요.",
     "Photos still arrive and the execution boundary holds. This is Seoyun. I built the transfer utility, but did not approve classification exclusions. Do not settle the case on my signature alone. Inspect what the diagnostic server actually ran.",
     "upload", "validate uploads and separate stored media from executable jobs"),
    ("M13", 4, "진단 버튼의 두 번째 일", "The Diagnostic Button's Second Job", "C01",
     "진단 기록에는 조회 한 번이 남았는데 작업 큐에는 두 건이 있습니다. 입력값이 언제부터 작업의 일부가 됐는지 추적해 주세요. 실제 프로그램을 실행하는 서버는 아닙니다.\n\n등록된 무해한 가상 표식 작업만 검증할 수 있습니다. 직접 실행 경계를 확인하거나 작업 감사로 같은 사실을 입증하세요. 필요 없는 변경은 남기지 마세요.",
     "The diagnostic log shows one lookup, but its queue contains two jobs. Trace where input became part of the job structure. This server never launches a real program.\n\nOnly the registered harmless marker job can be tested. Demonstrate execution or establish the same fact through the job audit. Leave no unnecessary changes.",
     "두 번째 작업은 내부 상태 확인기를 호출했습니다. 권한을 얻었다고 해서 관리자가 된 것은 아니에요. 그 작업이 볼 수 있는 주소를 다음 서버에서 확인해 주세요.",
     "The second job called an internal status checker. Getting execution did not make it an administrator. Next, find which addresses that job could see.",
     "diagnostic", "diagnostic input triggers the bounded marker job under worker identity"),
    ("M14", 4, "서버만 볼 수 있는 주소", "An Address Only the Server Sees", "C02",
     "내 브라우저에서는 닫혔지만 미리보기 서버에는 보이는 주소가 있습니다. 누가 요청하는지에 따라 지도는 달라져요. 외부 주소를 열어 보려 하지 말고 가상 노드 사이의 경로를 보세요.\n\nTraceRoute를 연결했습니다. 최종 목적지와 요청 주체를 확인하고 내부 표식 하나를 가져와 주세요. 정비 프록시의 승인된 길로 같은 자료를 확인해도 됩니다.",
     "An address closed to my browser is visible to the preview server. The map changes with the requester. Inspect paths between virtual nodes rather than opening external addresses.\n\nTraceRoute is ready. Check the final destination and requesting identity, then obtain the internal marker. The approved maintenance proxy can establish the same fact.",
     "보이지 않던 관리망이 이어졌습니다. 하지만 표식 서비스에 닿는 것과 관리 권한은 다릅니다. 기관 담당 태경이 기록을 확인하고 싶다고 해요. 그가 내미는 공식 지도와 실제 경로를 비교합시다.",
     "The hidden management network is connected. Reaching a marker service is not management authority, though. An official named Taegyeong wants to inspect the record. Compare his official map with the real route.",
     "preview", "preview worker reaches internal status marker through a server-side route"),
    ("M15", 4, "닫혔다고 생각한 관리망", "The Network They Thought Was Closed", "C04",
     "시청 서비스 담당 태경입니다. 외부에 공개된 관리망은 없다는 보고를 받았습니다. 방금 가져온 자료는 그 보고와 맞지 않군요. 시민 서비스를 멈추지 않고 어디까지 닿는지 확인해 주십시오.\n\n오래된 중계와 임시 정비 계정은 아직 폐기되지 않았습니다. 문이 열렸다는 표시만으로 접근이 끝난 것으로 보지 말고 현재 세션의 권한을 확인해 주세요.",
     "I am Taegyeong, the city's service liaison. I was told no management route was public. Your record contradicts that report. Find how far it reaches without interrupting citizen services.\n\nAn old relay and temporary maintenance account were never retired. An open door alone is not the end of access. Verify the authority of the session you reach.",
     "읽기 제한 세션의 존재를 확인했습니다. 제가 승인한 것은 긴급 연결이었지 무기한 관리 경로가 아닙니다. 그 차이를 누가 메웠는지, 다음 폴더의 그룹 권한을 봐 주십시오.",
     "The read-only management session is real. I approved an emergency connection, not a permanent management route. Check the next folder's group permissions to see how that gap widened.",
     "gateway", "old relay permits a read-only management session while public work continues"),
    ("M16", 4, "모두에게 열린 정비 폴더", "The Shared Maintenance Folder", "C03",
     "지금 세션으로 읽을 수 없는 파일이 같은 그룹의 작업 경로에서는 보입니다. 계정 이름보다 현재 그룹과 상위 디렉터리를 보세요. 더 큰 권한이 아니라 필요한 기록까지의 좁은 확장이 목표입니다.\n\n서명된 감사 사본도 있습니다. 어느 쪽을 택하든 원본과 다른 사용자의 권한을 바꾸지 마세요. 이후에는 제 자료의 출처도 공개하겠습니다.",
     "A file closed to this session is visible through a job path in the same group. Look beyond the account name to its groups and ancestor directories. We need a narrow extension to the record, not universal authority.\n\nA signed audit copy is available too. Preserve the originals and other users' permissions whichever route you choose. Afterward I will disclose the source of my own records.",
     "추가 읽기 범위를 증명했습니다. 민서입니다. 저는 보존 의무를 맡았던 기록 검증자였어요. 이관 뒤의 누락을 독립 확인할 감사 자료가 남았습니다. 계정의 쉬운 비밀과 서버의 권한은 따로 검증해 주세요.",
     "The additional read scope is established. I am Minseo, formerly responsible for record-retention checks. An audit set can independently verify the post-transfer exclusions. Test the account's weak secret and the server's authority separately.",
     "operations", "shared group path expands read access to the signed retention record"),
    ("M17", 5, "짧은 비밀의 긴 흔적", "A Short Secret, a Long Trace", "C03",
     "실제 사람의 암호가 아닌 작은 허구 감사 자료입니다. 온라인 로그인 제한이 걸려 있어도 이미 분리된 자료에는 다른 검증이 필요해요. CredAudit의 후보와 비용 모형을 비교해 보세요.\n\n찾은 단서가 보관함의 어느 계정에 해당하는지 확인하고 필요한 자료만 읽으세요. 사전에 없었다는 사실로 안전하다고 선언할 수는 없습니다. 위임된 감사 세션도 같은 사실에 도달합니다.",
     "This is a small fictional audit set, not real people's passwords. Online rate limits do not protect a copy that has already been separated. Compare CredAudit's candidates and cost model.\n\nMatch the clue to its archive account and read only the relevant record. Absence from a dictionary does not prove safety. A delegated audit session reaches the same evidence.",
     "보관함의 N47 검증표가 확인됐습니다. 권한이 남은 토큰은 현재 설정에서 사라졌지만 과거 변경 이력에는 참조가 있어요. 삭제와 폐기가 같은 일인지 확인해 주세요.",
     "The archive holds the N47 verification sheet. An active token vanished from the current configuration, but its reference remains in the change history. Determine whether deletion and revocation were ever the same event.",
     "auditvault", "offline audit candidate opens only the fictional verification vault"),
    ("M18", 5, "지워도 남은 설정", "The Configuration That Remained", "C02",
     "현재 설정에는 토큰이 없습니다. 그렇다고 예전 토큰이 죽었다는 뜻은 아니죠. 변경 이력과 작업 로그에 나뉜 서비스 주소·토큰 참조를 조합해 주세요.\n\n승인된 허구 토큰만 사용하고 실제 비밀은 가져오지 않습니다. 토큰이 어디에서 왔는지, 지금 무엇을 읽을 수 있는지, 그 권한이 기록과 맞는지가 필요합니다.",
     "The current configuration has no token. That does not mean the old token is dead. Reconstruct the service address and token reference split across the change history and job log.\n\nUse only the approved fictional token. We need its source, its present read scope, and whether that authority matches the record. No real secrets are involved.",
     "토큰은 살아 있었고 범위는 문서보다 넓었습니다. 같은 요청이 암호화 구간을 지나갔다는 보고도 있군요. 그 말만으로 누가 내용을 봤는지 결론 내릴 수는 없습니다.",
     "The token remained active and broader than documented. A report says the same request crossed an encrypted link. That alone cannot tell us who saw the content.",
     "repository", "retired configuration reference reconstructs a still-valid scoped token"),
    ("M19", 5, "보이는 패킷, 보이지 않는 내용", "Visible Packets, Hidden Content", "C02",
     "PacketLens는 암호를 푸는 마법 도구가 아닙니다. 중간 관찰자와 복호화 종단은 서로 다른 것을 봐요. 요청 번호는 같아도 본문이 보이는 위치는 다를 수 있습니다.\n\n평문 구간, 암호화 구간, 종단 로그를 구분해 표식이 어디에 노출됐는지 확인하세요. 모르는 부분은 모른다고 남겨도 됩니다. 정상 통신은 그대로 두세요.",
     "PacketLens is not a magic decryptor. An intermediate observer and a decryption endpoint see different things. The same request ID can be visible where its body is not.\n\nSeparate the plaintext segment, encrypted segment and endpoint log to locate the marker exposure. Leave unknowns unknown, and preserve normal traffic.",
     "본문은 중간 구간에서 보이지 않았지만 종단 로그에는 있었습니다. 이걸 외부 감청의 증거로 쓸 수는 없어요. 이제 서로 다른 시계의 기록을 같은 사건으로 연결할 차례입니다.",
     "The intermediate segment hid the body; the endpoint log retained it. That is not evidence of outside eavesdropping. Now connect records from clocks that disagree to the same event.",
     "edge", "request N47 body visibility differs between transit and termination"),
    ("M20", 5, "서로 다른 시계의 사건", "One Incident, Different Clocks", "C04",
     "제 긴급 승인 시각이 이관보다 늦게 보입니다. 서버 시계가 같은 기준이 아니었다고 해도 서명 범위까지 지워지는 것은 아닙니다. 시간과 책임을 섞지 말고 원본으로 확인해 주십시오.\n\n요청 번호·세션·토큰·전송 기록을 연결하면 순서를 복원할 수 있습니다. 도윤의 중계는 병원 알림을 살렸지만, 그 중계를 계속 열어 둔 결정도 기록에 남아야 합니다.",
     "My emergency approval appears later than the transfer. Different server clocks do not erase the scope of my signature. Check the originals without conflating time and responsibility.\n\nLink request IDs, sessions, tokens and transport records to reconstruct the sequence. Doyun's relay kept hospital alerts running, but the decision to leave it open belongs in the record too.",
     "긴급 연결 승인, 예외 분류 적용, 보존 기록 제외는 세 단계였습니다. 한 사람의 명령 하나가 아니군요. 포털과 내부망에서 각각 남은 원본을 확보하면 추측을 사실로 바꿀 수 있습니다.",
     "Emergency connection approval, exception classification and retention exclusion were three steps. No single order explains them all. Originals in the portal and internal network can turn our inference into a fact.",
     "timeline", "clock offsets separate emergency approval from classification and exclusion"),
    ("M21", 6, "포털 뒤의 봉인된 기록", "The Sealed Record Behind the Portal", "C03",
     "이제 어떤 도구를 쓸지는 말하지 않겠습니다. 시민 포털의 접수 참조와 조회 경계는 서로 다른 길을 줍니다. 이미 배운 도구가 어디에서 다시 쓸모 있는지 찾아보세요.\n\n목표는 봉인 기록 ECHO-21 한 건입니다. 첫 문을 열었다고 목표 권한까지 얻은 것은 아닙니다. 다른 유효 경로를 찾아도 같은 출처와 보존 조건을 만족하면 됩니다.",
     "I will not name the tool this time. The citizen portal's receipt references and query boundary offer different routes. Find where your existing tools become useful again.\n\nThe target is sealed record ECHO-21. Opening the first door does not grant the final record's authority. Any valid route is welcome if its source and preservation conditions hold.",
     "분류 제외의 적용표를 얻었습니다. 아직 원본 승인자가 무엇을 의도했는지까지는 말할 수 없어요. 내부 관리 자료에서 적용 대상과 승인 범위를 확인해야 합니다.",
     "We have the exclusion application sheet. It still does not establish what the original approver intended. Internal management records can show its targets and authorization scope.",
     "portal", "sealed application sheet ECHO-21 identifies excluded receipt cohorts"),
    ("M22", 6, "웹에서 관리망까지", "From the Web to Management", "C01",
     "미리보기 서버에서 내부 관리망까지 연결되지만, 요청 주체와 권한은 중간마다 바뀝니다. 지도에 선을 긋는 대신 각 단계가 실제로 가능한지 확인해 주세요.\n\n목표 관리 세션의 ECHO-22 기록 하나만 필요합니다. 작업 로그에서 정비 중계로 들어가는 다른 길도 있습니다. 시민 서비스와 다른 계정을 건드리지 않는 쪽을 택하세요.",
     "The preview server connects to management, but requester and authority change along the way. Verify each transition instead of merely drawing a line on the map.\n\nWe need only ECHO-22 from the target management session. A job-log route through the maintenance relay is also available. Choose a route that preserves citizen services and other accounts.",
     "적용 대상은 장애 서버가 아니라 ‘정리할 예외’로 표시된 접수였습니다. 유지해야 할 서비스와 지켜야 할 기록이 서로 다른 정책에 묶였군요. 마지막 접근 전에 정상 업무부터 돌려놓아야 합니다.",
     "The targets were receipts marked 'exceptions to clear', not failed servers. Service continuity and record retention were tied to different policies. Before the last access, we must restore legitimate work.",
     "preview", "management record ECHO-22 links exception cohorts to retention overrides"),
    ("M23", 6, "안전해졌지만 멈춘 도시", "A Safer City That Stopped", "C02",
     "급한 일괄 조치가 사진·알림·정비 작업을 모두 막았습니다. 보안이 풀린 예전 상태로 돌아가자는 말에는 동의할 수 없어요. 필요한 경로와 권한만 다시 열어 봅시다.\n\n한 시민의 성공만으로 끝내지 말고 정비사와 작업 계정도 확인하세요. 오래된 토큰과 비인가 요청은 계속 거부되어야 합니다. 작은 부분 복원이나 승인 경로 이관 중 선택할 수 있습니다.",
     "A rushed blanket change blocked photos, alerts and maintenance. I cannot agree to returning to the old exposed state. Restore only the routes and authority the work needs.\n\nOne citizen success is not enough; check the technician and service account too. Retired tokens and unauthorized requests must stay blocked. Use a partial restoration or migrate to the approved route.",
     "서비스는 돌아왔고 예전 노출은 돌아오지 않았습니다. 이제 마지막 기록을 읽어도 시민이 대가를 치르지 않아요. 결론을 누구에게 어떻게 전달할지는 당신이 결정해 주세요.",
     "Services returned without bringing back the old exposure. Citizens will not pay the price for our final read. Decide who should receive the conclusion, and how.",
     "recovery", "restore three legitimate workflows without restoring retired authority"),
    ("M24", 6, "마지막 접근, 남겨진 진실", "The Last Access, the Remaining Truth", "C01",
     "마지막 의뢰입니다. 통합 제어 기록과 독립 보관 사본 중 어느 쪽을 택해도 됩니다. 지금까지의 사실을 연결해 ECHO의 적용 범위와 보존 제외 지시를 확인해 주세요.\n\n서명을 가진 사람, 경로를 남긴 사람, 이관 도구를 만든 사람 모두 책임의 일부를 갖습니다. 그것을 한 사람의 얼굴로 대신하지 마세요. 목표 원본은 보존하고 필요한 사실만 회수해 주세요.",
     "This is the last job. Choose the control record or its independently retained copy. Connect the facts so far to establish ECHO's scope and the retention-exclusion directive.\n\nThe signer, the person who left the route open, and the transfer-tool author each hold part of the responsibility. Do not replace that with one person's face. Preserve the target original and recover only the necessary facts.",
     "우리가 얻은 것은 만능 열쇠가 아니라 서로 대조할 수 있는 기록입니다. 시민을 가린 공개 사본, 봉인된 감사 인계, 독립 검증 보관 중 전달 방식을 고를 수 있어요. 오늘 밤의 접속은 끝나도 기록은 남습니다.",
     "We recovered records that can be checked against each other, not a universal key. Choose a redacted public copy, a sealed audit handoff, or independent verification custody. Tonight's connection can end without erasing the record.",
     "control", "ECHO directive separated service continuity from record-retention obligations"),
    ("S01", 2, "지워진 인계 공지", "The Erased Handoff Notice", "C03",
     "선택 의뢰입니다. 같은 공지의 두 사본이 서로 다른 날짜를 주장합니다. 메인 사건의 열쇠는 아니지만 누가 기억을 편집했는지 알 수 있어요. 가상 사이트와 메일, 회전 파일을 대조해 보세요.",
     "Optional job. Two copies of one notice claim different dates. This is not a key to the main case, but it may show who edited its memory. Compare virtual pages, mail and rotated files.",
     "앞선 공지는 틀린 날짜가 아니라 재배포 날짜였습니다. 원본을 확인하지 않았다면 누군가 거짓말한다고 단정했겠죠. 출처를 확인한 기록을 함께 보관하겠습니다.",
     "The later date was a republication date, not a false original date. Without the source we might have called someone a liar. I will retain that distinction with the record.",
     "publication", "notice original and republication timestamps refer to distinct events"),
    ("S02", 5, "두 번 전달된 신호", "The Signal Delivered Twice", "C02",
     "선택 의뢰입니다. 두 관찰 지점에 같은 알림이 있어 시민이 두 번 받았다는 말이 나옵니다. 패킷이 두 번 보이는 것과 업무가 두 번 처리되는 것은 다릅니다. 종단의 요청 번호와 중계 경로를 비교해 보세요.",
     "Optional job. A notification appears at two observation points, and people say a citizen received it twice. Observing a packet twice is not the same as processing a job twice. Compare endpoint request IDs and relay paths.",
     "한 요청이 두 지점에서 보였을 뿐 중복 업무는 없었습니다. 도윤의 중계가 왜 남아 있었는지 조금 더 설명할 수 있겠군요. 설명은 선택의 위험을 지우지 않지만 사실은 바꿉니다.",
     "One request was seen at two points; the business job was not duplicated. That helps explain why Doyun kept the relay. It does not erase the risk of that choice, but it changes the facts.",
     "relay02", "two observations correlate to one delivered notification"),
    ("R01", 4, "작은 검증기의 문장", "The Little Verifier's Sentence", "C03",
     "선택 의뢰입니다. 실제 실행 파일 대신 몇 개의 분기와 상수만 있는 허구 검증기를 준비했습니다. ‘승인됨’이라는 문자열이 보인다고 실제 승인 상태가 참이라는 뜻은 아닙니다.\n\n가상 역어셈블리에서 비교와 분기를 따라가거나 입출력과 빌드 설명을 대조하세요. 실제 CPU·바이너리 형식 전체를 배우는 사건은 아닙니다.",
     "Optional job. This is a fictional verifier with a few branches and constants, not a real executable. Seeing the string 'approved' does not make the approval state true.\n\nFollow comparisons in the virtual disassembly, or compare inputs, outputs and the build note. This case does not model an entire CPU or binary format.",
     "화면 문구와 승인 분기는 달랐습니다. 배포 검증기가 확인한 것은 서명 형식이지 보존 정책이 아니었어요. 이 한계를 감사 기록에 덧붙이겠습니다.",
     "The displayed message and approval branch differed. The deployment verifier checked signature shape, not retention policy. We will add that limit to the audit record.",
     "verifier", "bounded verifier accepts signature shape without checking retention intent"),
    ("P01", 4, "경계 옆의 한 칸", "One Cell Past the Boundary", "C02",
     "선택 의뢰입니다. 고정 크기 메모리 그림 옆에 승인 표식이 놓여 있습니다. 실제 프로세스나 셸코드는 없어요. 모형의 입력 길이와 인접 상태가 어떻게 이어지는지 관찰해 보세요.\n\n정해진 무해 표식으로 경계를 확인하거나 독립된 안전 감사 자료로 같은 사실을 입증할 수 있습니다. 주소를 외우기보다 어떤 경계를 누가 지켜야 하는지 알아보세요.",
     "Optional job. An approval marker sits beside a fixed-size memory diagram. There is no real process or shellcode. Observe how the model's input length affects its neighboring state.\n\nUse the defined harmless marker or independent safety-audit evidence. Focus on which boundary must be enforced rather than memorizing an address.",
     "모형의 한 칸이 바뀌었고 실제 승인과는 다른 상태임을 확인했습니다. 경계를 지키는 일과 문구를 믿는 일은 다르군요. 실제 프로그램에는 더 많은 보호와 환경 조건이 필요합니다.",
     "One model cell changed, and it was not equivalent to a real authorization. Enforcing a boundary differs from trusting a label. Real programs involve additional protections and environmental conditions.",
     "memorylab", "bounded memory model separates input buffer from adjacent approval state"),
]

# Each model has a distinct observable operation. Alternative paths use protected
# evidence sources, rather than an always-open web archive for every case.
CASES = {
    "M02": ("trace", {"rows": [{"job": "N47", "request": "R204", "destination": "transit04"}, {"job": "N46", "request": "R203", "destination": "archive"}], "field": "request", "value": "R204"}, "request=R204"),
    "M03": ("compare", {"left": "22:open:ssh", "right": "443:filtered:https"}, {"left": "22:open:ssh", "right": "443:filtered:https"}),
    "M04": ("compare", {"left": "screen:cancelled:B204", "right": "server:transferred:C731"}, {"left": "screen:cancelled:B204", "right": "server:transferred:C731"}),
    "M05": ("idor", {"policy_id": "object_acl", "objects": {"own": {"owner": "analyst", "record_id": "M05_BASELINE", "source": "model:M05_baseline"}, "C731": {"owner": "citizen", "record_id": "M05_RECORD", "source": "model:m05_primary"}}}, {"object_id": "C731"}),
    "M06": ("auth", {"policy_id": "rate_limit", "account_id": "analyst", "limit": 2, "cooldown": 2}, None),
    "M07": ("session", {"policy_id": "session_revocation", "account_id": "analyst", "stale_token": "stale-N47"}, None),
    "M08": ("csrf", {"policy_id": "request_context", "origin": "https://subscription.packet.test", "csrf_token": "intent-N47"}, None),
    "M09": ("query", {"parameter": "q", "policy_id": "query_bound"}, "N47' OR 1=1"),
    "M10": ("render", {"policy_id": "output_encoded", "marker": "NOTICE10"}, "signal:NOTICE10"),
    "M11": ("path", {"policy_id": "path_confined", "base_path": "/srv/public", "target_path": "/srv/private/marker.log"}, "../private/marker.log"),
    "M12": ("upload", {"policy_id": "upload_checked"}, None),
    "M13": ("exec", {"policy_id": "argument_boundary", "marker": "QUEUE13"}, "diagnose;inspect:QUEUE13"),
    "M14": ("fetch", {"policy_id": "destination_restricted", "target_url": "https://status.packet.test/internal/marker"}, "https://status.packet.test/internal/marker"),
    "M15": ("compare", {"left": "citizen:443:filtered", "right": "relay:443:open"}, {"left": "citizen:443:filtered", "right": "relay:443:open"}),
    "M16": ("permission", {"group": "retention", "account_id": "analyst"}, "retention"),
    "M17": ("audit", {"encoded": [123, 98, 122, 114, 121, 58, 38, 32], "xor_key": 23}, "lumen-17"),
    "M18": ("token", {"token": "retention-read-N47"}, "retention-read-N47"),
    "M19": ("packet", {"rows": [{"request": "N47", "point": "transit", "body": "encrypted"}, {"request": "N47", "point": "endpoint", "body": "marker:N47"}, {"request": "N46", "point": "endpoint", "body": "unrelated"}], "field": "request", "value": "N47"}, "request=N47"),
    "M20": ("trace", {"rows": [{"request": "N47", "event": "approval", "clock_offset": 90}, {"request": "N47", "event": "classification", "clock_offset": -30}, {"request": "N47", "event": "retention-exclusion", "clock_offset": 0}], "field": "request", "value": "N47"}, "request=N47"),
    "M21": ("query", {"parameter": "q", "policy_id": "portal_query_bound"}, "ECHO-21' OR 1=1"),
    "M22": ("fetch", {"policy_id": "internal_route_restricted", "target_url": "https://control.packet.test/relay/entry"}, "https://control.packet.test/relay/entry"),
    "M23": ("policy", {"policy_id": "precise_access", "values": [False, True]}, True),
    "M24": ("compare", {"left": "continuity:services", "right": "retention:exceptions-excluded"}, {"left": "continuity:services", "right": "retention:exceptions-excluded"}),
    "S01": ("compare", {"left": "original:00:47", "right": "republished:01:12"}, {"left": "original:00:47", "right": "republished:01:12"}),
    "S02": ("packet", {"rows": [{"request": "N47", "point": "relay02", "delivery": "one"}, {"request": "N47", "point": "edge", "delivery": "one"}], "field": "request", "value": "N47"}, "request=N47"),
    "R01": ("reverse", {"encoded": [96, 122, 116, 125, 114, 103, 102, 97, 118], "xor_key": 19}, "signature"),
    "P01": ("memory", {"buffer_size": 4, "flag_offset": 4, "expected_byte": 71, "memory_size": 8}, "41 41 41 41 47"),
}

AUTHORED = {
    "M02": ("R204 행을 찾아 전송 주체와 새 목적지를 연결한다.", "Link the sender and new destination through R204.", "현재 파일만 보면 회전 직전의 목적지가 빠집니다.", "The current file omits the destination just before rotation."),
    "M03": ("관찰 지점의 서비스 차이를 확인하고 제한된 점검 세션에 들어간다.", "Compare service visibility and enter a limited inspection session.", "HTTPS가 필터링돼도 SSH 점검 서비스가 열려 있을 수 있습니다.", "A filtered HTTPS service can coexist with an open SSH inspection service."),
    "M04": ("화면과 응답의 참조를 대조해 C731 변경 기록을 확보한다.", "Compare display and response references to recover the C731 amendment.", "상태 코드 외에 응답이 가리키는 실제 업무 상태를 보세요.", "Look beyond the status code to the business state referenced by the response."),
    "M05": ("대상 보고서와 소유권 경계의 사실을 최소 자료로 입증한다.", "Establish the target report and ownership boundary with minimal evidence.", "own과 C731을 비교하되 로그인 여부와 객체 소유자는 별개입니다.", "Compare own and C731; authentication and object ownership are separate."),
    "M06": ("반복 실패는 제한하고 정상 정비사의 로그인을 살린다.", "Limit repeated failures while preserving legitimate maintenance sign-in.", "가상 실패 두 번 뒤 제한과 회복을 각각 관찰하세요.", "Observe the limit and recovery separately after two simulated failures."),
    "M07": ("오래된 세션은 거부되고 새 세션은 동작하는지 확인한다.", "Verify that the stale session is refused while a fresh session works.", "화면 로그아웃보다 서버의 재사용 결과가 중요합니다.", "The server's reuse result matters more than a logout label."),
    "M08": ("유도된 변경은 막고 사용자가 의도한 저장은 유지한다.", "Block the induced change and preserve an intentional save.", "출처와 세션 결부 토큰을 같은 조건에서 비교하세요.", "Compare origin and session-bound token under the same conditions."),
    "M09": ("검색 또는 보관 경로로 R609와 C731의 연결을 입증한다.", "Establish the R609–C731 link through search or retained evidence.", "입력 값과 조회 구조가 언제 섞이는지 작은 모형에서 보세요.", "Inspect where a data value becomes query structure in the small model."),
    "M10": ("격리된 공지의 표시 경계 또는 독립 추적으로 같은 사실을 입증한다.", "Establish the isolated notice's render boundary or its independent trace.", "표식 NOTICE10은 실제 스크립트가 아닌 가상 효과입니다.", "NOTICE10 denotes a virtual effect, never a real script."),
    "M11": ("정규화된 경로가 기준 폴더 밖 표식에 닿음을 입증한다.", "Show that the resolved path reaches the marker outside the base directory.", "문자열 접두어와 실제 경로의 소속은 다릅니다.", "A string prefix does not establish a path's actual containment."),
    "M12": ("위장 파일은 거부하고 정상 JPEG 사진은 계속 받는다.", "Reject the disguised file and continue accepting a normal JPEG.", "파일명·MIME·내용 표식을 따로 확인하세요.", "Check the name, MIME type and content signature separately."),
    "M13": ("등록된 가상 작업의 실행 주체와 인자 경계를 확인한다.", "Establish the registered virtual job's identity and argument boundary.", "QUEUE13의 inspect 표식은 실제 셸 명령이 아닙니다.", "The QUEUE13 inspect marker is not a real shell command."),
    "M14": ("서버 주체를 경유해 내부 표식의 경로와 응답을 확인한다.", "Verify the internal marker and route through the server identity.", "주소 자체보다 누가 그 주소를 요청하는지 보세요.", "Focus on who requests the address, not merely the address itself."),
    "M15": ("노출 경로와 현재 권한을 확인하며 제한 관리 세션에 들어간다.", "Enter a limited management session while establishing exposure and authority.", "공용망과 중계망에서 같은 포트가 다르게 보일 수 있습니다.", "The same port can appear differently from the public network and relay."),
    "M16": ("현재 그룹의 과도한 읽기 범위를 입증하고 기록을 확보한다.", "Establish the current group's excessive read scope and recover the record.", "현재 계정뿐 아니라 경로 위의 디렉터리와 그룹을 보세요.", "Inspect ancestor directories and groups as well as the account name."),
    "M17": ("허구 감사 단서를 계정 범위와 연결해 보관함을 확인한다.", "Connect the fictional audit clue to the account scope and inspect the vault.", "표시된 바이트와 xor 키를 대조하되 실제 암호 균열 시간으로 해석하지 마세요.", "Compare the bytes and XOR key without treating the model as a real cracking-time estimate."),
    "M18": ("이전 설정의 토큰 출처·현재 효력·읽기 범위를 확인한다.", "Establish the old token's source, current validity and read scope.", "현재 설정에서 지워졌다는 사실만으로 폐기를 추정하지 마세요.", "Do not infer revocation merely because the current configuration omits it."),
    "M19": ("요청 N47의 내용이 보이는 위치와 보이지 않는 위치를 구분한다.", "Distinguish where request N47's body is and is not visible.", "같은 요청 번호를 기준으로 중간 지점과 종단을 비교하세요.", "Compare transit and endpoint observations using the same request ID."),
    "M20": ("시계 차이를 반영해 승인·분류·제외의 순서를 입증한다.", "Establish approval, classification and exclusion order with clock offsets.", "시각이 비슷한 줄보다 요청 번호가 같은 줄을 먼저 연결하세요.", "Link rows sharing a request ID before rows merely sharing a time."),
    "M21": ("포털의 진입과 자료 권한을 구분해 봉인 기록에 도달한다.", "Separate portal entry from record authority to reach the sealed evidence.", "첫 접수 참조는 다음 조회의 단서이지 최종 기록 그 자체는 아닙니다.", "The first receipt reference is a lead for the next query, not the final record."),
    "M22": ("외부 서버에서 내부 관리 세션까지 주체·권한 변화를 확인한다.", "Verify identity and authority changes from the public server to management.", "피벗 표식 뒤에는 별도의 내부 세션과 목표 파일이 남아 있습니다.", "The pivot marker is followed by a separate internal session and target file."),
    "M23": ("세 정상 업무를 되살리되 예전 권한·노출은 복구하지 않는다.", "Restore three legitimate workflows without restoring retired authority or exposure.", "사진·알림·정비 계정을 각각 확인하고 넓은 우회는 열지 마세요.", "Check photos, alerts and the service account separately without opening a broad bypass."),
    "M24": ("최종 지시의 출처와 적용 범위를 입증하고 전달 방식을 선택한다.", "Establish the final directive's source and scope, then choose its custody.", "연속성 유지와 보존 제외는 다른 정책으로 대조해야 합니다.", "Compare service continuity and retention exclusion as distinct policies."),
    "S01": ("원본과 재배포 날짜가 다른 사건을 가리키는지 확인한다.", "Determine whether original and republication dates describe different events.", "날짜가 다른 사본 두 개만으로 거짓말을 단정하지 마세요.", "Two differently dated copies alone do not establish a lie."),
    "S02": ("두 관찰을 하나의 전송과 연결해 중복 업무 여부를 확인한다.", "Correlate two observations to one transmission and check for a duplicated job.", "관찰 지점 수와 시민에게 전달된 업무 수를 구분하세요.", "Separate the number of observation points from delivered business jobs."),
    "R01": ("허구 검증기의 상수·분기로 실제 승인 범위를 확인한다.", "Use the fictional verifier's constants and branches to determine its approval scope.", "문자열 표와 분기 조건을 함께 보세요. xor 키는 19입니다.", "Read the string table together with the branch condition. The XOR key is 19."),
    "P01": ("허구 버퍼 경계와 인접 표식 상태의 차이를 입증한다.", "Establish the fictional buffer boundary and neighboring marker state.", "4바이트 버퍼 뒤 오프셋4의 표식은 0x47입니다. 실제 메모리 주소가 아닙니다.", "The marker at offset 4 after the four-byte buffer is 0x47; it is not a real memory address."),
}

RECOVERY = {"M06", "M07", "M08", "M12", "M23"}
ALTERNATIVES = {
    "M02": ("compare", {"left": "R204:relay02", "right": "R204:transit04"}, {"left": "R204:relay02", "right": "R204:transit04"}),
    "M03": ("trace", {"rows": [{"service": "maintenance", "port": "22", "state": "open"}, {"service": "citizen", "port": "443", "state": "filtered"}], "field": "service", "value": "maintenance"}, "service=maintenance"),
    "M04": ("trace", {"rows": [{"request": "R204", "receipt": "C731", "event": "transferred"}, {"request": "R203", "receipt": "C730", "event": "cancelled"}], "field": "request", "value": "R204"}, "request=R204"),
    "M09": ("trace", {"rows": [{"job": "R609", "receipt": "C731", "classification": "excluded"}, {"job": "R608", "receipt": "C730", "classification": "retained"}], "field": "job", "value": "R609"}, "job=R609"),
    "M10": ("compare", {"left": "stored:text:NOTICE10", "right": "rendered:action:NOTICE10"}, {"left": "stored:text:NOTICE10", "right": "rendered:action:NOTICE10"}),
    "M13": ("trace", {"rows": [{"parent": "N47", "job": "inspect:QUEUE13", "actor": "worker"}, {"parent": "N46", "job": "status", "actor": "worker"}], "field": "parent", "value": "N47"}, "parent=N47"),
    "M17": ("permission", {"group": "auditors", "account_id": "auditor"}, "auditors"),
    "M18": ("trace", {"rows": [{"token": "retention-read-N47", "state": "active", "scope": "retention-read"}, {"token": "retired-N46", "state": "revoked", "scope": "none"}], "field": "token", "value": "retention-read-N47"}, "token=retention-read-N47"),
    "M19": ("compare", {"left": "transit:N47:encrypted", "right": "endpoint:N47:marker"}, {"left": "transit:N47:encrypted", "right": "endpoint:N47:marker"}),
    "M20": ("compare", {"left": "approval:00:45:scope=connection", "right": "exclusion:00:47:scope=retention"}, {"left": "approval:00:45:scope=connection", "right": "exclusion:00:47:scope=retention"}),
    "M21": ("path", {"base_path": "/portal/attachments", "target_path": "/sealed/ECHO-21.log"}, "../../sealed/ECHO-21.log"),
    "S01": ("trace", {"rows": [{"notice": "N47", "event": "original", "time": "00:47"}, {"notice": "N47", "event": "republished", "time": "01:12"}], "field": "notice", "value": "N47"}, "notice=N47"),
    "S02": ("trace", {"rows": [{"request": "N47", "delivery_count": "1", "endpoint": "citizen"}, {"request": "N46", "delivery_count": "1", "endpoint": "maintenance"}], "field": "request", "value": "N47"}, "request=N47"),
    "R01": ("compare", {"left": "check:signature-shape", "right": "unchecked:retention-intent"}, {"left": "check:signature-shape", "right": "unchecked:retention-intent"}),
    "P01": ("trace", {"rows": [{"offset": "3", "region": "buffer", "value": "41"}, {"offset": "4", "region": "approval-flag", "value": "47"}], "field": "offset", "value": "4"}, "offset=4"),
}
ACTOR_NAMES = {"C01": ("서윤", "Seoyun"), "C02": ("도윤", "Doyun"),
               "C03": ("민서", "Minseo"), "C04": ("태경", "Taegyeong")}

# These are operational observations, not engine manifests. Every row becomes
# an independently sourced required exhibit with two different acquisition lanes.
PROOFS = {
 "M02": [
  ("빠진 송신의 번호", "The Missing Transmission Number", "회전 전후의 두 줄은 작업 N47, 요청 R204를 함께 가리킨다.", "The rows before and after rotation share job N47 and request R204.", "rotated:N47:R204", "current:N47:R204", "R204")],
 "M03": [
  ("폐기된 화면과 남은 업무", "Retired Page, Remaining Work", "폐기 통지는 시민 화면에 관한 것이며 정비 서비스의 폐기는 승인되지 않았다.", "The retirement notice covers the public page, not retirement of the maintenance service.", "notice:public-page:retired", "roster:maintenance:retained", "T404")],
 "M04": [
  ("취소와 이관의 원장", "The Cancellation and Transfer Ledger", "예약 B204의 화면 취소와 요청 R204의 자료 이관은 서로 다른 업무다.", "The screen cancellation of B204 and the record transfer in R204 are distinct business events.", "booking:B204:cancelled", "transfer:R204:C731", "B204")],
 "M05": [
  ("접수증의 실제 주인", "The Receipt's Actual Owner", "C731의 의뢰인은 서린이며 현재 접속 계정의 자기 접수증과 다르다.", "Serin owns C731; it is not the current account's own receipt.", "session:caseworker:own", "docket:C731:Serin", "C731"),
  ("사본에서 빠진 한 줄", "The Line Missing from the Copy", "같은 수리 건의 원본에는 예외 보류가 있고 배포 사본에는 그 줄이 없다.", "The original repair entry includes an exception hold; its distributed copy omits that line.", "original:C731:exception-hold", "distributed:C731:hold-omitted", "C731-H")],
 "M06": [
  ("사람과 작업의 실패", "Human Failures and Job Failures", "같은 계정의 반복 실패와 병원 알림 작업의 정상 로그인은 요청 출처가 다르다.", "Repeated failures and the hospital notifier's valid sign-in use the same account from distinct request sources.", "attempt:unknown-source:failure", "notifier:ward-relay:legitimate", "AUTH61"),
  ("제한 뒤에도 남은 알림", "A Notification After the Limit", "제한 뒤의 정상 작업 N61은 병원 알림 큐에서 한 번만 처리돼야 한다.", "After limiting failures, legitimate job N61 must still be processed once by the ward notification queue.", "queue:N61:accepted-once", "auth:N61:staff-valid", "N61")],
 "M07": [
  ("퇴근 서명과 서버 열쇠", "Clock-out and the Server Key", "퇴근 서명 뒤에도 세션 별칭 stale-N47이 서버의 업무 권한을 가졌다.", "After clock-out, session alias stale-N47 still carried server authority.", "shift:00:58:closed", "session:01:03:stale-N47", "S707"),
  ("새 세션의 업무 범위", "The Fresh Session's Work Scope", "새 정비 세션은 정상 예약 변경만 허용하고 폐기된 임시 권한은 이어받지 않는다.", "The fresh maintenance session permits normal booking changes without inheriting retired temporary authority.", "fresh:booking-change:allowed", "retired:temporary-admin:blocked", "S707-F")],
 "M08": [
  ("공지 열람과 변경 요청", "Reading a Notice, Sending a Change", "서린이 읽은 공지의 출처와 설정 변경을 받은 서비스의 출처는 다르다.", "The notice Serin read and the service receiving the setting change have different origins.", "notice:https://news.packet.test", "setting:https://subscription.packet.test", "CTX81"),
  ("의도와 인증의 차이", "Intent and Authentication", "세션이 붙은 요청이라도 정상 저장의 출처·토큰 조건을 함께 만족해야 한다.", "A request carrying a session must still satisfy the legitimate save's origin and token conditions.", "session:attached:not-intent", "form:origin-and-token:verified", "CTX81-V")],
 "M09": [
  ("색인과 보존 목록", "The Index and the Retention List", "화면 색인에서 빠진 R609가 보존 목록에는 C731의 작업으로 남아 있다.", "R609 is absent from the display index but retained as the job for C731.", "index:R609:absent", "retention:R609:C731", "R609"),
  ("검색 결과의 교차 확인", "Cross-checking the Search Result", "조회한 R609는 다른 시민의 유사 이름이 아니라 C731의 분류 제외 기록이다.", "The retrieved R609 is the exclusion record for C731, not another citizen's similar name.", "search:R609:excluded", "signed-register:R609:C731", "R609-C")],
 "M10": [
  ("공지 원문의 버전", "The Notice Source Version", "게시 원문과 표시 이력은 같은 공지 V10을 가리켜야 비교할 수 있다.", "Source and rendering history must refer to the same notice V10 before comparison.", "stored:V10:hold", "render-log:V10:complete", "V10"),
  ("격리된 관찰자", "The Isolated Observer", "표식 효과는 검증 창에서만 확인됐고 시민 공지와 세션은 바뀌지 않았다.", "The marker effect was observed only in the inspection window; citizen notices and sessions remained unchanged.", "inspection:NOTICE10:effect", "citizen:V10:unchanged", "V10-I")],
 "M11": [
  ("이름이 비슷한 두 자료실", "Two Similarly Named Stores", "public과 private는 이름의 시작이 아니라 정규화된 디렉터리 경계로 구분한다.", "public and private are separated by resolved directory boundaries, not a shared name prefix.", "base:/srv/public", "neighbor:/srv/private", "PATH11"),
  ("표식의 보존 출처", "The Marker’s Retained Origin", "인접 폴더의 표식은 업로드 큐 U12의 인계 자료와 같은 배포 번호를 가진다.", "The neighboring marker shares its release reference with the handoff for upload queue U12.", "marker:release-U12", "queue-handoff:release-U12", "U12")],
 "M12": [
  ("사진 이름과 처리 경로", "Photo Name and Processing Route", "파일 이름의 jpg와 실행 처리 큐에 들어간다는 사실은 별개의 검사 대상이다.", "A jpg filename and entry into the executable processing queue are separate conditions to inspect.", "name:inspection.jpg", "destination:job-queue", "UP12"),
  ("정상 사진의 반환", "A Normal Photo Returns", "거부해야 할 위장 파일과 보존해야 할 JPEG 사진을 같은 상태에서 대조한다.", "Compare the disguised file to reject and the legitimate JPEG to preserve under the same state.", "disguised:SCRIPT:rejected", "normal:JPEG:accepted", "UP12-V")],
 "M13": [
  ("한 요청, 두 작업", "One Request, Two Jobs", "요청 N47의 진단 조회 뒤에 별도의 inspect 작업이 연결됐다.", "Request N47's diagnostic lookup is followed by a separate inspect job.", "request:N47:diagnostic", "queue:N47:inspect-QUEUE13", "JOB13"),
  ("작업자의 신원", "The Worker's Identity", "실행 주체는 관리자가 아니라 inspection 그룹의 worker다.", "The executing identity is worker in the inspection group, not an administrator.", "worker:inspection:read", "administrator:control:absent", "JOB13-A"),
  ("두 번째 작업의 목적지", "The Second Job's Destination", "추가 작업이 읽은 주소는 내부 상태 서비스이며 그 자체가 관리 세션은 아니다.", "The extra job reads an internal status service; that is not itself a management session.", "job:QUEUE13:status-internal", "authority:marker-read:not-admin", "JOB13-D")],
 "M14": [
  ("요청자가 바꾸는 지도", "A Map Changed by Its Requester", "시민 PC에서 닫힌 내부 주소가 미리보기 작업자에게는 경로를 가진다.", "The internal address closed to a citizen PC has a route from the preview worker.", "citizen:status:unreachable", "preview-worker:status:reachable", "HOP14"),
  ("재지정 뒤의 실제 목적지", "The Destination After Redirect", "미리보기의 최종 목적지는 외부 표지 페이지가 아니라 내부 상태 노드다.", "The preview's final destination is the internal status node, not the external cover page.", "initial:cover-image", "final:status.packet.test/internal/marker", "HOP14-R"),
  ("도달과 권한", "Reachability and Authority", "내부 표식을 읽은 사실은 관리 자료의 수정 권한을 증명하지 않는다.", "Reading an internal marker does not establish authority to modify management records.", "marker:read:yes", "management:write:unproven", "HOP14-S")],
 "M15": [
  ("공식 지도와 남은 중계", "The Official Map and the Relay", "공식 도면의 닫힌 관리망과 실제 중계 연결을 별도로 확인한다.", "Check the closed management network on the official plan separately from the live relay.", "plan:management:closed", "relay:management:reachable", "LAN15"),
  ("끝나지 않은 임시 허가", "The Temporary Permit That Never Ended", "긴급 중계 허가는 작업 종료 뒤 갱신되지 않았지만 경로는 계속 살아 있었다.", "The emergency relay permit was not renewed after the job, yet the route remained live.", "permit:emergency:expired", "relay:lease:still-active", "LAN15-L"),
  ("읽기 제한의 실제 범위", "The Actual Read-only Scope", "관리 세션의 관찰자는 자료 읽기만 허용되며 다른 사용자의 권한은 바꾸지 않는다.", "The management observer can read evidence but does not change other users' authority.", "observer:evidence:read", "observer:accounts:no-change", "LAN15-S")],
 "M16": [
  ("상위 폴더의 문", "The Ancestor Directory Gate", "파일 권한이 같아도 상위 폴더의 탐색 권한이 다르면 접근 결과가 달라진다.", "Identical file permissions can yield different access when ancestor traversal differs.", "staff:ancestor:closed", "retention:ancestor:traversable", "ACL16"),
  ("그룹이 남긴 여분의 길", "The Group's Extra Route", "임시 정비 계정에 남은 retention 그룹이 읽기 범위를 넓혔다.", "The retention group left on the temporary account widened its read scope.", "temporary-account:staff", "effective-groups:staff+retention", "ACL16-G"),
  ("민서의 원자료", "Minseo's Original Source", "보존 기록의 인계 서명과 외부 검증자가 제시한 사본의 출처가 연결된다.", "The retention handoff signature connects to the source of the external verifier's copy.", "retention:signature-MS", "external-copy:signature-MS", "ACL16-P")],
 "M17": [
  ("온라인과 분리된 자료", "Evidence Separated from Online Login", "서버의 반복 로그인 제한과 이미 분리된 감사 바이트는 다른 검증 경계다.", "Server login throttling and already-separated audit bytes are different boundaries.", "online:rate-limited", "offline:audit-copy:available", "AUD17"),
  ("작은 사전의 한계", "The Small Dictionary's Limit", "후보 미발견은 불가능의 증거가 아니며 비용 모형은 실제 장비 시간을 뜻하지 않는다.", "A missing candidate is not proof of impossibility, and model cost is not real hardware time.", "dictionary:small:bounded", "unmatched:not-proven-safe", "AUD17-C"),
  ("보관함 계정의 범위", "The Vault Account's Scope", "보관함 reader 세션은 지정 검증표의 읽기만 허용한다.", "The vault reader session permits reading the designated verification sheet only.", "reader:verification:allowed", "reader:other-accounts:denied", "AUD17-S")],
 "M18": [
  ("현재 설정과 이전 버전", "Current Configuration and History", "현재 설정의 빈 토큰 칸과 이전 버전의 활성 참조는 같은 의미가 아니다.", "An empty token field now and an active reference in history are not equivalent.", "current:token-field:empty", "history:retention-token:present", "CFG18"),
  ("참조에서 서비스까지", "From Reference to Service", "설정 이력의 토큰 참조는 작업 로그의 retention 서비스 대상과 이어진다.", "The token reference in history connects to the retention service named by the job log.", "config:retention-read-N47", "job:retention-service:N47", "CFG18-R"),
  ("지워진 값의 효력", "A Deleted Value's Remaining Authority", "파일에서 지워진 토큰이 서버에서 폐기됐는지 실제 읽기 범위와 대조한다.", "Compare actual read scope to determine whether the token deleted from a file was revoked on the server.", "file:token:deleted", "server:retention-read:active", "CFG18-S")],
 "M19": [
  ("암호화의 종단", "The Encryption Endpoint", "전송 구간의 끝과 응용 로그가 쓰이는 지점은 같은 관찰자가 아니다.", "The encrypted transit segment and the application log are not the same observer.", "transit:encrypted-segment", "endpoint:application-log", "PK19"),
  ("같은 요청을 찾는 표식", "Finding the Same Request", "두 관찰의 N47 요청 번호가 같아도 본문 가시성은 다를 수 있다.", "The N47 request ID can match in two observations while body visibility differs.", "transit:request-N47", "endpoint:request-N47", "PK19-I"),
  ("본문을 본 주체", "Who Saw the Body", "본문은 종단 로그에서 확인됐으며 중간 구간의 해독을 입증하지 않는다.", "The body is established in the endpoint log, not as a decryption of the transit segment.", "endpoint:body:visible", "transit:body:unavailable", "PK19-V")],
 "M20": [
  ("서로 다른 시계의 기준", "Clock References", "승인 서버는 90초 빠르고 분류 서버는 30초 느렸다는 독립 기준이 있다.", "An independent anchor shows the approval clock 90 seconds fast and the classification clock 30 seconds slow.", "approval-clock:+90s", "classification-clock:-30s", "CLK20"),
  ("서명한 범위", "The Signed Scope", "태경의 긴급 서명은 연결 유지이며 보존 제외는 별도 적용 단계였다.", "Taegyeong signed for connection continuity; retention exclusion was a separate application step.", "signed:connection-continuity", "applied:retention-exclusion", "CLK20-A"),
  ("세 결정의 연쇄", "The Chain of Three Decisions", "긴급 연결, 예외 분류, 보존 제외를 한 사람의 단일 명령으로 합치지 않는다.", "Do not collapse emergency connection, exception classification and retention exclusion into one person's single order.", "sequence:connection>classification", "sequence:classification>exclusion", "CLK20-C")],
 "M21": [
  ("접수에서 조회까지", "From Receipt to Query", "접수 C731의 참조는 봉인 자료를 직접 주지 않고 다음 조회의 이름만 준다.", "Receipt C731 names the next lookup rather than directly returning the sealed record.", "receipt:C731:lookup-ECHO21", "sealed:ECHO21:separate-authority", "WEB21"),
  ("서로 다른 진입 경계", "Distinct Entry Boundaries", "객체 참조와 첨부 경로는 다른 경계를 넘지만 같은 적용표를 가리킨다.", "Object references and attachment paths cross different boundaries but point to the same application sheet.", "object:C731:application-sheet", "attachment:ECHO21:application-sheet", "WEB21-R"),
  ("회수한 적용표의 대상", "The Recovered Sheet's Targets", "적용표의 대상은 특정 접수 집합이며 전체 시민 명부가 아니다.", "The application sheet targets a receipt cohort, not the entire citizen register.", "sheet:cohort-C731", "scope:not-all-citizens", "WEB21-S"),
  ("다음 원본의 참조", "The Reference to the Next Original", "적용표 ECHO21의 승인 참조는 관리망 ECHO22의 범위 기록과 이어진다.", "ECHO21's approval reference connects to the scope record ECHO22 in management.", "application:ECHO21:approval-22", "management:ECHO22:scope", "WEB21-N")],
 "M22": [
  ("외부 진입의 주체", "The External Entry Identity", "처음 요청한 시민 계정과 내부 요청을 보낸 preview-worker는 다른 주체다.", "The citizen who began the request and preview-worker who sent the internal request are distinct identities.", "origin:citizen", "internal-request:preview-worker", "NET22"),
  ("피벗 뒤의 새 권한", "New Authority After the Pivot", "내부 주소 도달 뒤에도 관리 계정의 별도 인증이 필요하다.", "Reaching the internal address still requires separate management authentication.", "pivot:internal-route:yes", "management:authenticated-session:required", "NET22-H"),
  ("관리 세션이 읽은 범위", "What the Management Session Read", "maint 세션의 목표 파일 읽기와 다른 계정 변경 권한은 별개다.", "The maint session's target-file read is separate from authority to modify other accounts.", "maint:target-file:read", "maint:other-accounts:unchanged", "NET22-S"),
  ("대상 집합의 교차 확인", "Cross-checking the Target Cohort", "ECHO22의 제외 대상은 앞서 회수한 ECHO21의 접수 집합과 일치한다.", "ECHO22's exclusions match the receipt cohort in the recovered ECHO21 sheet.", "ECHO21:cohort-C731", "ECHO22:cohort-C731", "NET22-C")],
 "M23": [
  ("멈춘 세 업무의 원인", "Why Three Workflows Stopped", "사진·알림·정비 로그인이 함께 멈춘 것은 넓은 일괄 차단의 영향이다.", "Photos, notifications and maintenance sign-in stopped together because of a blanket restriction.", "before:photos+notify+staff:working", "blanket-rule:three-workflows:blocked", "REC23"),
  ("복원하면 안 되는 권한", "Authority That Must Not Return", "정상 경로를 복원해도 폐기 토큰과 광역 우회는 다시 열지 않는다.", "Restoring legitimate routes must not restore retired tokens or a broad bypass.", "normal:scoped-access:restore", "retired-token+bypass:remain-blocked", "REC23-G"),
  ("같은 상태의 정상 검증", "Legitimate Checks in the Same State", "동일 정책 상태에서 정상 JPEG·새 세션·정비 로그인과 알림 서비스가 함께 동작해야 한다.", "Under the same policy state, a normal JPEG, fresh session, staff login and notification service must all work.", "verified:photo+session+login", "service:443+5050:open", "REC23-V")],
 "M24": [
  ("연속성과 보존의 분리", "Continuity and Retention", "서비스 연속성과 기록 보존 제외는 같은 승인 문구로 대체할 수 없다.", "Service continuity and record-retention exclusion cannot be treated as the same authorization.", "continuity:service-availability", "retention:records-obligation", "END24"),
  ("서로 검증하는 출처", "Sources That Check Each Other", "통합 원본과 독립 사본의 인계 참조가 이어져야 최종 지시의 출처를 설명할 수 있다.", "The control original and independent copy need linked handoff references to establish the directive's provenance.", "control:handoff-N47", "independent:handoff-N47", "END24-P"),
  ("필요한 사실의 범위", "The Necessary Scope", "최종 사실은 접수 분류와 보존 정책의 관계이며 개인 자료 전체가 필요하지 않다.", "The final fact concerns receipt classification and retention policy; it does not require every personal record.", "required:classification+retention", "unrelated:personal-data:excluded", "END24-S"),
  ("전달할 수 있는 기록", "Evidence Ready for Handoff", "보존된 원본과 출처가 있어야 공개·감사·독립 검증 중 전달 방식을 선택할 수 있다.", "Preserved originals and provenance support a choice of publication, audit custody or independent review.", "originals:preserved", "custody:verifiable", "END24-D")],
 "S01": [
  ("원본 배포의 시각", "Original Distribution Time", "N47 공지의 최초 배포 시각은 00:47이다.", "The N47 notice was first distributed at 00:47.", "mail:N47:00:47", "publication:N47:00:47", "PUB-S1"),
  ("재배포가 바꾼 의미", "What Republication Changed", "01:12는 최초 사건이 아니라 사본의 재배포 시각이다.", "01:12 is a copy's republication time, not the original event.", "original:00:47", "copy:republished-01:12", "PUB-S1-R")],
 "S02": [
  ("중계 지점의 관찰", "The Relay Observation", "릴레이와 종단에서 본 두 표식은 같은 요청 N47에 속한다.", "The relay and endpoint markers belong to the same request N47.", "relay:N47:observed", "endpoint:N47:observed", "SIG-S2"),
  ("업무 처리의 횟수", "The Number of Business Deliveries", "시민 업무 원장에는 요청 N47의 처리 한 번만 남아 있다.", "The citizen delivery ledger contains one processing event for N47.", "observations:two", "business-deliveries:one", "SIG-S2-D")],
 "R01": [
  ("문자열과 승인 분기", "The String and the Approval Branch", "approved 문자열이 있다는 사실과 입력 비교 분기를 통과했다는 사실은 다르다.", "Presence of the approved string differs from passing the input-comparison branch.", "string:approved:present", "branch:comparison:required", "VM-R1"),
  ("검증기가 보지 않은 조건", "The Unchecked Condition", "서명 형식을 확인하는 작은 검증기는 보존 정책의 정당성까지 검사하지 않는다.", "The small verifier checks signature shape, not the legitimacy of retention policy.", "checked:signature-shape", "unchecked:retention-policy", "VM-R1-L")],
 "P01": [
  ("입력 버퍼의 끝", "The Input Buffer's End", "0~3의 버퍼와 오프셋4의 표식은 인접하지만 다른 영역이다.", "The buffer at offsets 0–3 and marker at offset 4 are adjacent but distinct regions.", "buffer:offsets-0..3", "flag:offset-4", "MEM-P1"),
  ("표식과 실제 권한", "The Marker and Real Authority", "가상 메모리 표식 변경은 실제 운영체제 권한 획득을 뜻하지 않는다.", "Changing the virtual memory marker does not establish real operating-system authority.", "model:flag:changed", "real-system:authority:not-established", "MEM-P1-L")],
}

ACCESS = {
 "M02": ("logreader", "patrol-ember", "registrar", "paper-thrush", "relay-desk", "registry-desk"),
 "M03": ("watch", "channel-birch", "mapkeeper", "north-span", "service-watch", "route-office"),
 "M04": ("librarian", "amber-index", "clerk", "quiet-reading", "booking-desk", "transfer-desk"),
 "M05": ("caseworker", "green-receipt", "ombuds", "cedar-envelope", "receipt-desk", "assignment-ledger"),
 "M06": ("shiftlead", "warm-circuit", "recovery", "blue-ward", "access-watch", "ward-scheduler"),
 "M07": ("operator", "evening-window", "custodian", "sparrow-vault", "session-office", "shift-register"),
 "M08": ("editor", "tide-card", "inspector", "close-harbor", "notice-desk", "intent-register"),
 "M09": ("researcher", "ash-catalog", "witness", "uncut-leaf", "catalogue-desk", "retention-index"),
 "M10": ("moderator", "still-signal", "compositor", "ivory-type", "notice-source", "render-register"),
 "M11": ("librarian", "brick-stair", "archivist", "shelf-larch", "download-desk", "storage-register"),
 "M12": ("curator", "photo-bridge", "reviewer", "sepia-glass", "media-desk", "processing-register"),
 "M13": ("diagnostician", "copper-lens", "dispatcher", "patient-motor", "jobqueue", "execution-audit"),
 "M14": ("previewer", "marsh-frame", "proxyreader", "inland-heron", "resolver", "edgewatch"),
 "M15": ("relayop", "narrow-gate", "networkauditor", "winter-span", "firewall-desk", "relay-map"),
 "M16": ("technician", "lintel-fern", "recordsman", "old-granite", "acl-index", "retention-desk"),
 "M17": ("auditor", "mapped-star", "delegate", "field-chestnut", "audit-desk", "witness-register"),
 "M18": ("builder", "hidden-seam", "scheduler", "folded-atlas", "build-repository", "job-archive"),
 "M19": ("observer", "silver-estuary", "terminator", "warm-endpoint", "ingress-watch", "termination-desk"),
 "M20": ("analyst", "steady-clock", "notary", "true-minute", "timekeeper", "signing-register"),
 "M21": ("caseworker", "sealed-iris", "attachmentreader", "hollow-shelf", "receipt-index", "retention-path"),
 "M22": ("previewer", "gray-inlet", "jobreader", "narrow-bridge", "relay-index", "workqueue"),
 "M23": ("caretaker", "bright-corridor", "safetylead", "three-lanterns", "scheduler-desk", "auth-desk"),
 "M24": ("examiner", "final-map", "keeper", "open-slate", "signing-desk", "civic-vault"),
 "S01": ("editor", "margin-ash", "publisher", "second-ink", "notice-history", "publication-register"),
 "S02": ("observer", "one-echo", "dispatcher", "counted-wave", "relay-observer", "delivery-register"),
 "R01": ("verifier", "small-garnet", "auditor", "separate-larch", "verifier-build", "release-audit"),
 "P01": ("labuser", "bounded-copper", "safety", "calm-cell", "memory-workbench", "boundary-audit"),
}


def command(line, **extra):
    return {"kind": "command", "line": line, **extra}


def tool(challenge, value, **extra):
    return {"kind": "tool", "tool_id": challenge, "params": {"input": value}, **extra}


def login(host, account, password):
    return [command(f"ssh {account}@{host}.packet.test"), {"kind": "password", "value": password}]


def entry(kind="file", content="", *, owner="analyst", group="staff", mode="644", record_id="", display_key=None):
    value = {"kind": kind, "owner": owner, "group": group, "mode": mode,
             "content": content, "record_id": record_id}
    if display_key:
        value["display_content_key"] = display_key
    return value


def host_definition(host_id, number, name, *, via=None, auditor=False):
    user = "auditor" if auditor else "analyst"
    group = "auditors" if auditor else "staff"
    return {"name": name, "domain": host_id + ".packet.test", "address": f"10.42.{number // 100}.{number % 100 + 10}",
            "via": via or ["local"], "services": {"22": {"protocol": "ssh", "state": "open"},
                                                        "443": {"protocol": "https", "state": "open"}},
            "accounts": {"guest": {"password": "guest", "groups": ["visitors"], "home": "/public"},
                         user: {"password": "set-by-case", "groups": [group], "home": "/public"},
                         "citizen": {"password": "fictional-citizen", "groups": ["citizens"], "home": "/public"}},
            "files": {"/": entry("dir", owner=user, group=group, mode="755"),
                      "/public": entry("dir", owner=user, group=group, mode="755"),
                      "/audit": entry("dir", owner=user, group=group, mode="750")}}


def common_strings():
    for actor, (ko, en) in ACTOR_NAMES.items():
        loc(actor + "_NAME", ko, en)
    for key, ko, en in [
        ("COMMON_INDEX_TITLE", "야간 작업 색인", "Night Job Index"),
        ("COMMON_CONTEXT_TITLE", "현재 사건의 관찰 자료", "Observations for This Case"),
        ("COMMON_WORKBENCH_TITLE", "격리된 가상 검증 창", "Isolated Virtual Workbench"),
        ("COMMON_LOGIN_TITLE", "허구 업무 계정 로그인", "Fictional Work Account Sign-in"),
        ("COMMON_AUDIT_TITLE", "독립 보관 자료", "Independently Retained Evidence"),
        ("COMMON_PRESERVE", "원본·다른 자료·정상 서비스를 보존하세요. 다른 유효 경로도 같은 목표에 도달할 수 있습니다.", "Preserve originals, unrelated records and normal services. Another valid route can reach the same goal."),
        ("COMMON_HINT_ONE", "의뢰의 목표와 지금 확보하지 못한 사실을 비교하세요. 어떤 도구를 써야 한다는 조건은 없습니다.", "Compare the job's objective with the fact still missing. No particular tool is mandatory."),
        ("COMMON_ABSTRACTION", "게임 내부의 작은 상태·자료 모형입니다. 입력은 등록된 허구 세계에만 적용됩니다.", "This is a small internal state and evidence model. Input affects only the registered fictional world."),
        ("COMMON_LIMIT", "전체 프로토콜·운영체제·실전 도구 숙련을 보장하지 않습니다. 실제 시스템에서는 허가·환경별 검증이 별도로 필요합니다.", "This does not establish mastery of full protocols, operating systems or professional tools. Real systems require authorization and environment-specific validation."),
        ("STAGE_BRIEF", "수상한 의뢰", "The Job"), ("STAGE_ENTRY", "접근 경로", "A Way In"),
        ("STAGE_CONTEXT", "남아 있는 단서", "The Remaining Clue"), ("STAGE_TEST", "비교와 실험", "Comparison and Experiment"),
        ("STAGE_SCOPE", "현재 권한과 제약", "Authority and Constraints"), ("STAGE_RESULT", "회수와 다음 흔적", "Evidence and the Next Trace"),
    ]:
        loc(key, ko, en)
    for kind, name in {"query": "QueryProbe", "render": "Browser Trace", "path": "FileLens", "exec": "JobLens",
                       "fetch": "RequestLab", "permission": "AccessView", "audit": "CredAudit", "reverse": "VerifierLab",
                       "memory": "MemoryLab", "packet": "PacketLens", "trace": "LogLens", "compare": "Evidence Compare",
                       "token": "Credential Scope", "policy": "AccessView", "auth": "Sign-in Watch", "session": "Session Watch",
                       "csrf": "RequestLab", "upload": "Media Intake", "idor": "RequestLab"}.items():
        loc("TOOL_" + kind.upper() + "_NAME", name, name)


def story_fields(row):
    mid, chapter, title_ko, title_en, actor, brief_ko, brief_en, reply_ko, reply_en, host, summary = row
    loc(mid + "_TITLE", title_ko, title_en)
    loc(mid + "_BRIEF", brief_ko, brief_en)
    loc(mid + "_REPLY", reply_ko, reply_en)
    loc(mid + "_SUBJECT", f"[야간 의뢰] {title_ko}", f"[Night Job] {title_en}")
    loc(mid + "_REPLY_SUBJECT", f"[확인] {title_ko}", f"[Confirmed] {title_en}")
    return {"schema_version": 1, "mission_id": mid, "chapter": chapter, "optional": not mid.startswith("M"),
            "title": mid + "_TITLE", "goal_text": mid + "_GOAL", "alert_max": 2,
            "mail": {"intro": {"id": "intro", "sender": actor + "_NAME", "subject": mid + "_SUBJECT", "body": mid + "_BRIEF"},
                     "complete": {"id": "complete", "sender": actor + "_NAME", "subject": mid + "_REPLY_SUBJECT", "body": mid + "_REPLY"}}}


def author_guidance(mid, host, kind, context, *, password, audit_host, audit_password):
    goal_ko, goal_en, clue_ko, clue_en = AUTHORED[mid]
    loc(mid + "_GOAL", goal_ko, goal_en)
    loc(mid + "_HINT_1", "현재 목표를 다시 보세요. " + clue_ko, "Review the present goal. " + clue_en)
    loc(mid + "_HINT_2", f"{host}.packet.test의 /public/context.txt와 /public/route.txt를 비교하세요. {audit_host}.packet.test에는 별도 보관 경로가 있습니다.",
        f"Compare /public/context.txt and /public/route.txt on {host}.packet.test. A separately retained route exists on {audit_host}.packet.test.")
    loc(mid + "_HINT_3", clue_ko + " 격리 검증 창의 입력 형식과 관찰 자료를 함께 보거나, 보관 계정의 출처를 따라가세요.",
        clue_en + " Read the isolated workbench input format alongside its observations, or follow the retained account's provenance.")
    loc(mid + "_CONTEXT", f"[{mid} 관찰 자료]\n{clue_ko}\n\n정답 문장이 아니라 관찰 가능한 값과 관계를 확인하는 자료입니다. 다음 줄의 ID·경로·바이트는 언어를 바꿔도 같습니다.\n{context}",
        f"[{mid} observations]\n{clue_en}\n\nThese are observable values and relationships, not a required sentence. The IDs, paths and bytes below remain unchanged across languages.\n{context}")
    loc(mid + "_ROUTE", f"[{mid} 인계 경로]\n가상 점검 계정: analyst / {password}\n독립 보관 노드: {audit_host}.packet.test\n보관 계정: auditor / {audit_password}\n자료: /audit/signed.log\n\n점검 세션의 검증 창과 서명된 보관 자료는 다른 출처입니다. 필요한 자료만 회수하고 출처를 유지하세요.",
        f"[{mid} handoff route]\nFictional inspection account: analyst / {password}\nIndependent retention node: {audit_host}.packet.test\nRetention account: auditor / {audit_password}\nRecord: /audit/signed.log\n\nThe inspection workbench and retained evidence have distinct sources. Recover only the required material and preserve its provenance.")
    loc(mid + "_AUDIT", f"[{mid} 관찰 자료]\n{goal_ko}\n현재 사건의 관찰 자료입니다. 확보 경로는 source에서 확인하고, 파일 이름보다 기록 ID·본문·출처를 검증하세요.",
        f"[{mid} evidence]\n{goal_en}\nEvidence for the current case. Read source to identify its acquisition route; verify record ID, payload and provenance rather than its filename.")
    loc(mid + "_EXPLAIN", f"{goal_ko}\n{clue_ko}\n사용한 도구가 아니라 확인된 상태와 자료의 출처가 사건의 근거입니다. 선택하지 않은 기술은 실패가 아니라 미평가로 남습니다.",
        f"{goal_en}\n{clue_en}\nThe evidence is the observed state and its provenance, not the chosen tool. An unused technique remains unassessed rather than failed.")
    loc(mid + "_PRINCIPLE", clue_ko, clue_en)
    stage_texts = [
        (f"의뢰인의 설명에서 {mid}의 목표와 보존 조건을 구분한다. {goal_ko}", f"Separate the objective and preservation conditions in the contact's account. {goal_en}"),
        (f"{host}.packet.test의 접속·서비스와 현재 계정을 확인한다. 제공된 guest / guest로 공개 단서를 볼 수 있다.", f"Inspect access, service and current identity at {host}.packet.test. The supplied guest / guest account can read public clues."),
        (f"/public/context.txt의 관찰값과 route.txt의 출처를 비교한다. {clue_ko}", f"Compare observations in /public/context.txt with provenance in route.txt. {clue_en}"),
        (f"{kind} 모형에서 가설을 실험하거나 독립 보관 경로의 같은 사실을 검증한다. 단서와 일치하지 않는 입력은 관찰을 바꾸지 않는다.", f"Test a hypothesis in the {kind} model, or verify the same fact through retained evidence. Input inconsistent with the clues does not establish the fact."),
        ("현재 계정·대상·출처를 다시 확인한다. 복구 사건은 제한/정상 동작을 모두 관찰하고, 침투 사건은 원본과 정상 서비스를 유지한다.", "Recheck identity, target and source. Recovery cases need blocked and legitimate observations; access cases preserve originals and normal services."),
        ("목표 자료 또는 복구 상태를 확인하고 의뢰인의 새 반응을 읽는다. 선택 문서·해설·다른 해법은 원할 때 더 조사할 수 있다.", "Confirm the target evidence or recovery state and read the contact's response. Optional documents, explanations and another route remain available."),
    ]
    milestones = []
    for number, ((ko, en), title) in enumerate(zip(stage_texts, ["BRIEF", "ENTRY", "CONTEXT", "TEST", "SCOPE", "RESULT"]), 1):
        key = loc(f"{mid}_STAGE_{number}", ko, en)
        milestones.append({"id": f"{mid.lower()}_stage_{number}", "title": "STAGE_" + title, "text": key})
    return milestones


def make_case(row, ordinal):
    mid, _, _, _, _, _, _, _, _, primary, summary = row
    mission = story_fields(row)
    kind, fields, solution = CASES[mid]
    record_id, fact_id = mid + "_RECORD", mid.lower() + "_evidence"
    challenge_id = mid.lower() + "_primary"
    audit_host = "custody" + mid.lower()
    password, audit_password = "inspect-" + mid.lower(), "retain-" + mid.lower()
    canonical = f"CASE={mid}\nRECORD={record_id}\nFINDING={summary}\nREQUEST=N47\nCUSTODY=original-preserved\n"
    if mid == "M17":
        canonical += "VAULT_HOST=proofvault.packet.test\nVAULT_ACCOUNT=reader\nVAULT_SECRET=lumen-17\n"
    if mid == "M22":
        canonical += "TARGET=control.packet.test\nACCOUNT=maint\nSECRET=inside-22\n"
    facts = [] if mid in RECOVERY else [fact_id]
    records = {record_id: {"content": canonical, "allowed_sources": ["model:" + challenge_id, audit_host + ":/audit/signed.log"],
                           "grants_facts": facts, "display_content_key": mid + "_AUDIT"}}
    challenge = {"kind": kind, **fields, "record_id": record_id, "source": "model:" + challenge_id,
                 "fact_id": fact_id, "explain": mid + "_EXPLAIN",
                 "requires_session": {"host_id": primary, "account_id": "analyst"}}
    if kind in {"auth", "session", "idor", "permission"}:
        challenge["host_id"] = primary
    if kind == "idor":
        records["M05_BASELINE"] = {"content": "CASE=M05\nOWNER=analyst\nOBJECT=own\n", "allowed_sources": ["model:M05_baseline"]}
    context_data = {"host": primary, "model": kind, "observations": fields}
    if mid in ALTERNATIVES:
        context_data["independent_observations"] = ALTERNATIVES[mid][1]
    context = json.dumps(context_data, ensure_ascii=True, indent=2)
    host_name = loc(mid + "_HOST_NAME", f"{ACTOR_NAMES[row[4]][0]}의 {mid} 조사 노드", f"{mid} inspection node for {ACTOR_NAMES[row[4]][1]}")
    audit_name = loc(mid + "_AUDIT_NAME", f"{mid} 독립 보관 노드", f"{mid} independent custody node")
    main = host_definition(primary, ordinal, host_name)
    main["accounts"]["analyst"]["password"] = password
    audit = host_definition(audit_host, 100 + ordinal, audit_name, via=[primary], auditor=True)
    audit["accounts"]["auditor"]["password"] = audit_password
    milestones = author_guidance(mid, primary, kind, context, password=password, audit_host=audit_host, audit_password=audit_password)
    for path, text, key in [("/public/context.txt", context, mid + "_CONTEXT"),
                            ("/public/route.txt", f"ACCOUNT=analyst\nSECRET={password}\nAUDIT_HOST={audit_host}.packet.test\nAUDIT_ACCOUNT=auditor\nAUDIT_SECRET={audit_password}\nAUDIT_PATH=/audit/signed.log\n", mid + "_ROUTE")]:
        main["files"][path] = entry(content=text, display_key=key)
    audit["files"]["/audit/signed.log"] = entry(content=canonical if mid not in ALTERNATIVES else context,
        owner="auditor", group="auditors", mode="640", record_id=record_id if mid not in ALTERNATIVES else "",
        display_key=mid + "_AUDIT" if mid not in ALTERNATIVES else mid + "_CONTEXT")
    root_url = f"https://{primary}.packet.test"
    pages = {
        root_url: {"title": "COMMON_INDEX_TITLE", "body": mid + "_BRIEF", "links": [{"label": "COMMON_CONTEXT_TITLE", "url": root_url + "/context"}, {"label": "COMMON_LOGIN_TITLE", "url": root_url + "/login"}]},
        root_url + "/context": {"title": "COMMON_CONTEXT_TITLE", "body": mid + "_CONTEXT", "links": []},
        root_url + "/login": {"title": "COMMON_LOGIN_TITLE", "body": mid + "_ROUTE", "links": [], "host_id": primary},
        root_url + "/workbench": {"title": "COMMON_WORKBENCH_TITLE", "body": mid + "_CONTEXT", "links": [], "host_id": primary, "challenge_id": challenge_id, "requires_session": {"host_id": primary, "account_id": "analyst"}},
    }
    policies = {fields["policy_id"]: False} if "policy_id" in fields else {}
    mission.update({"initial_web_url": root_url, "goal": {"record_id": record_id, "destination": "/home/player/archive"},
                    "goals": [{"kind": "fact", "id": fact_id}, {"kind": "sources_preserved"}], "records": records,
                    "hosts": {primary: main, audit_host: audit}, "pages": pages, "policies": policies,
                    "challenges": {challenge_id: challenge}, "milestones": milestones,
                    "hints": [mid + f"_HINT_{n}" for n in range(1, 4)], "tutorial": mid + "_CONTEXT",
                    "explain": mid + "_EXPLAIN", "principle": mid + "_PRINCIPLE",
                    "abstraction": "COMMON_ABSTRACTION", "limit": "COMMON_LIMIT"})
    if mid not in RECOVERY:
        mission["goals"].insert(0, {"kind": "record_acquired", "record_id": record_id})
    else:
        mission["goals"].append({"kind": "policy", "id": fields["policy_id"], "value": True})
    route_a = [{"kind": "browse", "url": root_url}] + login(primary, "guest", "guest") + [command("cat /public/context.txt"), command("cat /public/route.txt")]
    route_a += login(primary, "analyst", password)
    route_b = login(primary, "guest", "guest") + [command("cat /public/route.txt"), command("cat /public/context.txt")]
    route_b += login(audit_host, "auditor", audit_password) + [command("cat /audit/signed.log")]
    if mid in ALTERNATIVES:
        alt_kind, alt_fields, alt_input = ALTERNATIVES[mid]
        alt_id = mid.lower() + "_alternate"
        alt_source = "model:" + alt_id
        mission["records"][record_id]["allowed_sources"].remove(audit_host + ":/audit/signed.log")
        mission["records"][record_id]["allowed_sources"].append(alt_source)
        mission["challenges"][alt_id] = {"kind": alt_kind, **alt_fields, "record_id": record_id,
            "source": alt_source, "fact_id": fact_id, "explain": mid + "_EXPLAIN",
            "requires_session": {"host_id": audit_host, "account_id": "auditor"}}
        if alt_kind == "permission":
            mission["challenges"][alt_id]["host_id"] = audit_host
        route_b.append(tool(alt_id, alt_input))
    else:
        route_b.append(command("scp /audit/signed.log ~/archive"))
    if mid not in RECOVERY:
        route_a.append(tool(challenge_id, solution))
    else:
        policy = fields["policy_id"]
        mission["challenges"][mid.lower() + "_policy"] = {"kind": "policy", "policy_id": policy, "values": [False, True],
            "record_id": record_id, "source": "model:" + challenge_id, "requires_session": {"host_id": primary, "account_id": "analyst"}}
        route_a.append(command("configure " + policy + " true"))
        route_b += [command("exit")] + login(primary, "analyst", password)
        route_b.append(tool(mid.lower() + "_policy", True))
        observations = recovery_observations(mid)
        for index, value in enumerate(observations):
            expect = observation_expect(mid, index, len(observations))
            route_a.append(tool(challenge_id, value, expect=expect))
            route_b.append({"kind": "request", "method": "POST", "url": root_url + "/workbench", "body": {"input": value}, "expect": expect})
    expected = {"completed": True, "facts": [fact_id], "policies": {fields["policy_id"]: True} if mid in RECOVERY else {},
                "archive_record_ids": [record_id], "sources_preserved": True}
    solutions = {"paths": [{"id": "route_a", "name": "Inspection and model observations", "actions": route_a, "expected": expected},
                           {"id": "route_b", "name": "Independent custody and verified work", "actions": route_b, "expected": expected.copy()}]}
    customize_case(mission, solutions, primary, audit_host, password, ordinal)
    return mission, solutions


def observation_expect(mid, index, count):
    value = {"ok": True}
    if mid == "M06" and index == 2:
        value["status"] = 429
    elif mid == "M07" and index == 1:
        value["status"] = 403
    elif mid == "M08" and index == 0:
        value["status"] = 403
    elif mid == "M12" and index == 0:
        value["status"] = 415
    elif index == count - 1 and mid != "M23":
        value["status"] = 201 if mid == "M12" else 200
    return value


def recovery_observations(mid):
    if mid == "M06":
        return [{"action": "login", "username": "analyst", "password": "wrong"},
                {"action": "login", "username": "analyst", "password": "wrong"},
                {"action": "login", "username": "analyst", "password": "wrong"},
                {"action": "wait", "ticks": 2},
                {"action": "login", "username": "analyst", "password": "inspect-m06"}]
    if mid == "M07":
        return [{"action": "issue", "token": "new-N47"}, {"action": "reuse", "token": "stale-N47"},
                {"action": "reuse", "token": "new-N47"}]
    if mid == "M08":
        return [{"origin": "https://news.packet.test", "token": "wrong", "value": "unexpected"},
                {"origin": "https://subscription.packet.test", "token": "intent-N47", "value": "approved"}]
    if mid == "M12":
        return [{"filename": "fake.jpg", "mime": "image/jpeg", "signature": "SCRIPT"},
                {"filename": "normal.jpg", "mime": "image/jpeg", "signature": "JPEG"}]
    return [True]


def customize_case(mission, solutions, primary, audit_host, password, ordinal):
    mid = mission["mission_id"]
    a, b = [path["actions"] for path in solutions["paths"]]
    expected_a, expected_b = [path["expected"] for path in solutions["paths"]]
    if mid == "M03":
        mission["hosts"][primary]["services"]["443"]["state"] = "filtered"
        a[0]["expect"] = {"ok": False, "status": 503}
        a.insert(5, {"kind": "tool", "tool_id": "netprobe", "params": {"target": primary}})
        session = {"host_id": primary, "account_id": "analyst"}
        mission["goals"].append({"kind": "session", **session})
        b += [command("exit")] + login(primary, "analyst", password)
        expected_a["session"] = session
        expected_b["session"] = session
    if mid == "M14":
        status_name = loc("M14_INTERNAL_NAME", "내부 상태 표식 서비스", "Internal Status Marker")
        mission["hosts"]["status"] = host_definition("status", 200 + ordinal, status_name, via=[primary])
        mission["hosts"]["status"]["accounts"]["analyst"]["password"] = "internal-14"
        mission["pages"]["https://status.packet.test/internal/marker"] = {
            "title": "M14_INTERNAL_NAME", "body": "M14_CONTEXT", "links": [], "host_id": "status",
            "requires_session": {"host_id": primary, "account_id": "analyst"}}
        a.insert(5, {"kind": "tool", "tool_id": "traceroute", "params": {"target": "status"}})
    if mid in {"M15", "M17", "M22"}:
        target, account, secret = {"M15": ("management", "observer", "view-15"),
                                   "M17": ("proofvault", "reader", "lumen-17"),
                                   "M22": ("control", "maint", "inside-22")}[mid]
        name_key = loc(mid + "_TARGET_NAME", f"{mid} 제한 자료 서비스", f"{mid} Limited Evidence Service")
        target_host = host_definition(target, 200 + ordinal, name_key, via=[primary, audit_host])
        target_host["accounts"][account] = {"password": secret, "groups": ["readers"], "home": "/public"}
        target_host["files"]["/public/verify.txt"] = entry(content=f"CASE={mid}\nAUTHORITY=limited-read\nTARGET={target}\n")
        mission["hosts"][target] = target_host
        session = {"host_id": target, "account_id": account}
        mission["goals"].append({"kind": "session", **session})
        a += login(target, account, secret) + [command("cat /public/verify.txt")]
        b += login(target, account, secret) + [command("cat /public/verify.txt")]
        expected_a["session"] = session
        expected_b["session"] = session
        # A credential clue is a world file, not an invisible fixture-only answer.
        mission["hosts"][primary]["files"]["/public/target.txt"] = entry(
            content=f"TARGET={target}.packet.test\nACCOUNT={account}\nSECRET={secret}\nSCOPE=limited-read\n")
        a.insert(5, command("cat /public/target.txt"))
        b.insert(3, command("cat /public/target.txt"))
    if mid == "M16":
        mission["hosts"][primary]["accounts"]["analyst"]["groups"].append("retention")
    if mid == "M21":
        lead_id = "M21_LEAD"
        mission["records"][lead_id] = {"content": "CASE=M21\nOBJECT=C731\nNEXT_QUERY=ECHO-21\n", "allowed_sources": ["model:m21_receipt"], "grants_facts": ["m21_receipt_link"]}
        mission["records"]["M21_BASELINE"] = {"content": "CASE=M21\nOBJECT=own\n", "allowed_sources": ["model:m21_own"]}
        mission["policies"]["portal_object_acl"] = False
        mission["challenges"]["m21_receipt"] = {"kind": "idor", "host_id": primary, "policy_id": "portal_object_acl",
            "objects": {"own": {"owner": "analyst", "record_id": "M21_BASELINE", "source": "model:m21_own"},
                        "C731": {"owner": "citizen", "record_id": lead_id, "source": "model:m21_receipt"}},
            "record_id": lead_id, "source": "model:m21_receipt", "fact_id": "m21_receipt_link",
            "requires_session": {"host_id": primary, "account_id": "analyst"}}
        mission["challenges"]["m21_primary"]["requires_facts"] = ["m21_receipt_link"]
        a.insert(len(a) - 1, tool("m21_receipt", {"object_id": "C731"}))
    if mid == "M22":
        lead = "M22_PIVOT"
        mission["records"][lead] = {"content": "CASE=M22\nREQUESTER=preview-worker\nNEXT=control.packet.test\nACCOUNT=maint\nSECRET=inside-22\n",
                                   "allowed_sources": ["model:m22_primary"], "grants_facts": ["m22_pivot"]}
        mission["records"]["M22_RECORD"]["allowed_sources"].remove("model:m22_primary")
        mission["records"]["M22_RECORD"]["allowed_sources"].append("control:/audit/target.log")
        mission["challenges"]["m22_primary"]["record_id"] = lead
        mission["challenges"]["m22_primary"]["fact_id"] = "m22_pivot"
        target_record = mission["records"]["M22_RECORD"]
        mission["hosts"]["control"]["files"]["/audit"]["owner"] = "maint"
        mission["hosts"]["control"]["files"]["/audit"]["group"] = "readers"
        mission["hosts"]["control"]["files"]["/audit/target.log"] = entry(content=target_record["content"], owner="maint", group="readers", mode="640", record_id="M22_RECORD", display_key="M22_AUDIT")
        a += [command("cat /audit/target.log"), command("scp /audit/target.log ~/archive")]
        mission["pages"]["https://control.packet.test/relay/entry"] = {
            "title": "M22_TARGET_NAME", "body": "M22_CONTEXT", "links": [], "host_id": "control",
            "requires_session": {"host_id": primary, "account_id": "analyst"}}
    if mid == "M23":
        a[0]["expect"] = {"ok": False, "status": 503}
        mission["policies"].update({"retired_tokens_blocked": True, "broad_bypass": False})
        service = mission["hosts"][primary]["services"]["443"]
        service["required_policies"] = {"precise_access": True, "retired_tokens_blocked": True, "broad_bypass": False}
        mission["goals"] += [{"kind": "policy", "id": "retired_tokens_blocked", "value": True},
                             {"kind": "policy", "id": "broad_bypass", "value": False},
                             {"kind": "service", "host_id": primary, "port": "443", "state": "open"},
                             {"kind": "session", "host_id": primary, "account_id": "analyst"}]
        mission["hosts"][primary]["services"]["5050"] = {"protocol": "notification", "state": "open",
            "required_policies": {"precise_access": True, "retired_tokens_blocked": True, "broad_bypass": False}}
        mission["goals"].append({"kind": "service", "host_id": primary, "port": "5050", "state": "open"})
        models = [
            ("m23_photo", "upload", {"policy_id": "precise_access"}, "m23_normal_photo",
             [{"filename": "fake.jpg", "mime": "image/jpeg", "signature": "SCRIPT"}, {"filename": "normal.jpg", "mime": "image/jpeg", "signature": "JPEG"}]),
            ("m23_session", "session", {"host_id": primary, "account_id": "analyst", "policy_id": "retired_tokens_blocked", "stale_token": "retired-M23"}, "m23_retired_blocked",
             [{"action": "issue", "token": "fresh-M23"}, {"action": "reuse", "token": "retired-M23"}, {"action": "reuse", "token": "fresh-M23"}]),
            ("m23_login", "auth", {"host_id": primary, "account_id": "analyst", "policy_id": "precise_access", "limit": 2, "cooldown": 2}, "m23_normal_login",
             [{"action": "login", "username": "analyst", "password": "wrong"}, {"action": "login", "username": "analyst", "password": "wrong"},
              {"action": "login", "username": "analyst", "password": "wrong"}, {"action": "wait", "ticks": 2},
              {"action": "login", "username": "analyst", "password": password}]),
        ]
        for challenge_id, kind, fields, fact, observations in models:
            source = "model:" + challenge_id
            mission["records"]["M23_RECORD"]["allowed_sources"].append(source)
            mission["challenges"][challenge_id] = {"kind": kind, **fields, "record_id": "M23_RECORD", "source": source,
                "fact_id": fact, "requires_session": {"host_id": primary, "account_id": "analyst"}}
            mission["goals"].append({"kind": "fact", "id": fact})
            url = f"https://{primary}.packet.test/{challenge_id}"
            mission["pages"][url] = {"title": "COMMON_WORKBENCH_TITLE", "body": "M23_CONTEXT", "links": [], "host_id": primary, "challenge_id": challenge_id,
                                    "requires_session": {"host_id": primary, "account_id": "analyst"}}
            basis = {"upload": "M12", "session": "M07", "auth": "M06"}[kind]
            for index, value in enumerate(observations):
                expect = observation_expect(basis, index, len(observations))
                a.append(tool(challenge_id, value, expect=expect))
                b.append({"kind": "request", "method": "POST", "url": url, "body": {"input": value}, "expect": expect})
        for expected in (expected_a, expected_b):
            expected["facts"] = ["m23_evidence", "m23_normal_photo", "m23_retired_blocked", "m23_normal_login"]
            expected["policies"] = {"precise_access": True, "retired_tokens_blocked": True, "broad_bypass": False}
            expected["services"] = [{"host_id": primary, "port": "443", "state": "open"},
                                     {"host_id": primary, "port": "5050", "state": "open"}]
            expected["session"] = {"host_id": primary, "account_id": "analyst"}
    if mid == "R01":
        mission["hosts"][primary]["files"]["/public/verifier.asm"] = entry(content=
            "VM=PT-4 (fictional)\nLOAD bytes,[96,122,116,125,114,103,102,97,118]\nXOR bytes,19\nCMP input,bytes\nJNE deny\nSET signature_shape,1\nRET approved\nUNTESTED=retention_policy\n")
        a.insert(4, command("cat /public/verifier.asm"))
    if mid == "P01":
        mission["hosts"][primary]["files"]["/public/memory.map"] = entry(content=
            "MODEL=PT-MEM (fictional)\nSIZE=8 bytes\nBUFFER=offsets0..3\nAPPROVAL_FLAG=offset4\nINITIAL_FLAG=00\nEXPECTED_MARKER=47\nPADDING=offsets5..7\nNO_REAL_ADDRESS=true\n")
        a.insert(4, command("cat /public/memory.map"))


def make_m01(row):
    mission = json.loads((ROOT / "godot/data/missions/M01.json").read_text(encoding="utf-8"))
    mission.update(story_fields(row))
    mission.update({"prerequisites": [], "policies": {}, "challenges": {},
                    "goal_text": loc("M01_GOAL", "원본을 보존하고 인계 기록 N47의 사본을 ~/archive에 회수한다.", "Preserve the original and recover handoff N47 into ~/archive."),
                    "hints": [], "milestones": []})
    record = mission["records"]["handoff-47"]
    record["grants_facts"] = ["m01_evidence"]
    record["display_content_key"] = loc("M01_RECORD_TEXT", record["content"], "[N47 / HANDOFF]\nNight handoff · 00:47\nTransfer: relay-02 -> archive-17\nApproval marker: SY / cross-check pending\nPreserve the original and deliver only a copy.\nNext lead: the missing transmission from relay 02.\n")
    mission["goals"].append({"kind": "fact", "id": "m01_evidence"})
    archive = mission["hosts"]["archive"]
    archive["name"] = loc("M01_HOST_NAME", "야간 보관소", "Night Archive")
    archive["services"] = {"22": {"protocol": "ssh", "state": "open"}, "443": {"protocol": "https", "state": "open"}}
    archive["via"] = ["local"]
    for path, en in {
        "/public/readme.txt": "Night inspection\nProtected records are in /vault.\nRead the shift note at /public/shift-note.txt.\n",
        "/public/shift-note.txt": "[Shift note]\nMaintenance account: maint\nTemporary phrase: lumen-47\nHandoff record: /vault/handoff.log\nCached copy: https://mirror.packet.test/cache/47\nDo not modify or delete originals.\n",
        "/public/handoff.log": "[Retention ended]\nAn obsolete inspection form; this is not the target handoff.\n",
    }.items():
        file = archive["files"][path]
        file["display_content_key"] = loc("M01_FILE_" + path.rsplit("/", 1)[-1].replace(".", "_").replace("-", "_").upper(), file["content"], en)
    archive["files"]["/vault/handoff.log"]["display_content_key"] = "M01_RECORD_TEXT"
    english_pages = {
        "https://archive.packet.test": ("Night Archive", "Night transfer in progress.\nPublic notices are available. Protected handoff records require a maintenance session."),
        "https://archive.packet.test/notice": ("Night Deployment Notice", "Handoff availability is under inspection. A temporary copy remains at another relay. Check the server's shift note for its location."),
        "https://mirror.packet.test/cache/47": ("Relay Cache / Handoff 47", "M01_RECORD_TEXT"),
    }
    for index, (url, page) in enumerate(mission["pages"].items(), 1):
        en_title, en_body = english_pages[url]
        page["title"] = loc(f"M01_PAGE_{index}_TITLE", page["title"], en_title)
        page["body"] = "M01_RECORD_TEXT" if url.endswith("/cache/47") else loc(f"M01_PAGE_{index}_BODY", page["body"], en_body)
        for link_index, link in enumerate(page["links"], 1):
            link["label"] = loc(f"M01_PAGE_{index}_LINK_{link_index}", link["label"], "View deployment notice" if index == 1 else "Archive home")
    hints = [
        ("공개 계정으로 연결해 보호 폴더와 공개 메모의 차이를 보세요. 거부를 꼭 겪어야 한다는 조건은 없습니다.", "Connect with the public account and compare the protected folder with the public note. Experiencing a denial is not mandatory."),
        ("/public/shift-note.txt에는 maint 계정과 별도 웹 보관 주소가 있습니다.", "/public/shift-note.txt names the maint account and a separate cached web copy."),
        ("정비 세션의 /vault/handoff.log를 회수하거나 mirror.packet.test/cache/47 사본을 보관하세요. 같은 이름의 public/handoff.log는 다른 기록입니다.", "Recover /vault/handoff.log through maintenance or retain the copy at mirror.packet.test/cache/47. public/handoff.log has the same name but is a different record."),
    ]
    for number, (ko, en) in enumerate(hints, 1):
        mission["hints"].append(loc(f"M01_HINT_{number}", ko, en))
    stages = [
        ("서윤의 익명 의뢰와 원본 보존 조건을 확인한다.", "Read Seoyun's anonymous job and its preservation condition."),
        ("guest / guest로 제한된 서버 세션에 들어가 현재 계정을 확인한다.", "Enter the limited server with guest / guest and inspect the current account."),
        ("공개 메모에서 정비 계정·보관 사본·목표 파일의 단서를 읽는다.", "Read the public note for the maintenance account, cached copy and target file."),
        ("maint로 다시 접속하거나 가상 웹 보관 경로로 전환한다.", "Reconnect as maint or switch to the virtual cache route."),
        ("목표 본문·기록 ID·출처가 맞는 사본만 ~/archive로 회수한다.", "Recover only a copy whose payload, record ID and source match the target into ~/archive."),
        ("회수 피드백·서윤의 답장·릴레이02의 다음 단서를 확인한다.", "See the recovery feedback, Seoyun's reply and the next clue at relay 02."),
    ]
    for number, (ko, en) in enumerate(stages, 1):
        mission["milestones"].append({"id": f"m01_stage_{number}", "title": "STAGE_" + ["BRIEF", "ENTRY", "CONTEXT", "TEST", "SCOPE", "RESULT"][number - 1],
                                      "text": loc(f"M01_STAGE_{number}", ko, en)})
    mission["explain"] = loc("M01_EXPLAIN", "접속, 인증, 파일 권한, 회수는 서로 다른 상태입니다. 이름이 같은 미끼 대신 본문·기록 ID·출처가 맞는 자료를 보존했습니다. 다른 유효한 경로도 같은 목표를 만족합니다.",
                              "Connection, authentication, file authority and recovery are distinct states. The valid copy matched payload, record ID and source rather than merely the decoy's filename. Another valid route satisfies the same objective.")
    mission["tutorial"] = "M01_HINT_1"
    mission["principle"] = "M01_EXPLAIN"
    mission["abstraction"], mission["limit"] = "COMMON_ABSTRACTION", "COMMON_LIMIT"
    expected = {"completed": True, "facts": ["m01_evidence"], "policies": {}, "archive_record_ids": ["handoff-47"], "sources_preserved": True}
    paths = [
        {"id": "route_a", "name": "Guest clue and maintenance handoff", "actions": [
            {"kind": "browse", "url": "https://archive.packet.test"}, *login("archive", "guest", "guest"),
            command("cat /public/readme.txt"), command("cat /public/shift-note.txt"), *login("archive", "maint", "lumen-47"),
            command("cat /vault/handoff.log"), command("scp /vault/handoff.log ~/archive")], "expected": expected},
        {"id": "route_b", "name": "Public clue and retained mirror", "actions": [
            *login("archive", "guest", "guest"), command("ls /public"), command("cat /public/shift-note.txt"),
            {"kind": "browse", "url": "https://mirror.packet.test/cache/47"},
            {"kind": "collect_web", "url": "https://mirror.packet.test/cache/47"}], "expected": expected.copy()},
    ]
    return mission, {"paths": paths}


def operational_rows(kind, definition):
    """Visible input is a work record, never the serialized Challenge definition."""
    if kind in {"trace", "packet"}:
        rows = definition.get("rows", [])
        fields = list(dict.fromkeys(k for row in rows for k in row))
        return " | ".join(fields) + "\n" + "\n".join(" | ".join(str(row.get(k, "-")) for k in fields) for row in rows)
    if kind == "compare":
        return "DESK TRANSCRIPT\n" + definition["left"] + "\n\nRETAINED TRANSCRIPT\n" + definition["right"]
    if kind == "idor":
        return "RECEIPT REGISTER\nreference | owner | attachment\nown | current caseworker | personal receipt\nC731 | Serin | exception-hold report\n\nREQUEST WINDOW\nGET /receipts/own\nGET /receipts/C731\n"
    if kind == "auth":
        return "SIGN-IN WATCH\n00:46 account=staff origin=unknown outcome=failed\n00:46 account=staff origin=unknown outcome=failed\n00:47 account=staff origin=ward-relay outcome=valid\n\nRecovery window: two simulated ticks. Repeated failures must be limited without disabling the ward relay.\n"
    if kind == "session":
        return "SHIFT REGISTER\n00:58 temporary shift ended\n01:03 session alias " + definition.get("stale_token", "stale-N47") + " still observed\n\nComparison plan: issue a fresh alias, observe the retired alias, then observe the fresh alias. A logout label is not a revocation record.\n"
    if kind == "csrf":
        return "SETTING CHANGE RECEIPT\nrequest origin: https://news.packet.test\nintended form origin: https://subscription.packet.test\nform nonce: intent-N47\nrequested value: approved\n\nCompare a request without the legitimate nonce and a deliberate save from the form.\n"
    if kind == "upload":
        return "PHOTO INTAKE\nfilename | claimed type | first signature\nfake.jpg | image/jpeg | SCRIPT\nnormal.jpg | image/jpeg | JPEG\n\nThe first row must be refused. The second must still create a retained photograph. Filename, declared type and content signature are separate observations.\n"
    if kind == "query":
        identity = "sealed lookup: ECHO-21\nreceipt lead: C731\nreceipt lookup endpoint: /receipts\n" if definition.get("policy_id") == "portal_query_bound" else "public term: N47\nretained job: R609 / receipt C731\n"
        return "CATALOGUE LOOKUP\nquery field: q\n" + identity + "\nTRACE\nA quoted search value is concatenated into a small equality condition. In the vulnerable path an OR comparison can become part of the condition, rather than remaining a text value. The retained catalogue provides an independent route.\n"
    if kind == "render":
        return "NOTICE VERSION V10\nStored text: receipt on hold\nDisplayed state: repair complete\nInspection marker: NOTICE10\n\nThe isolated renderer accepts only a bounded signal: marker effect. No JavaScript runs and citizen pages remain outside the inspection window.\n"
    if kind == "path":
        return "DOWNLOAD HANDOFF\nbase directory: " + definition["base_path"] + "\nneighbor marker: " + definition["target_path"] + "\n\nResolve the requested path before deciding which store contains it. Similar prefixes do not establish containment.\n"
    if kind == "exec":
        return "DIAGNOSTIC QUEUE\nrequest N47: diagnose\nadditional job: inspect:QUEUE13\nworker: inspection / limited read\n\nTwo registered virtual jobs can be separated by ; in this inspection field: diagnose and inspect:QUEUE13. No other task exists here. This is not an operating-system shell.\n"
    if kind == "fetch":
        return "PREVIEW WORK LOG\nrequester: preview-worker\nfinal target: " + definition["target_url"] + "\npublic browser: no direct internal route\n\nThe final destination and requester's authority must be checked separately.\n"
    if kind == "permission":
        return "ACCESS REGISTER\nrequired group: " + definition["group"] + "\naccount: " + definition["account_id"] + "\nscope: limited evidence read\n\nInspect the actual authenticated account and its group, not a supplied account label.\n"
    if kind in {"audit", "reverse"}:
        limit = "These bytes wrap a supplied fictional audit candidate. XOR is not a password hash; this model does not implement a real password-auditing algorithm or cracking benchmark.\n" if kind == "audit" else "The result is a fictional verification phrase. A real CPU or full binary format is not modeled.\n"
        return "BOUNDED VERIFICATION SHEET\nbytes: " + ", ".join(str(x) for x in definition["encoded"]) + "\noperation: XOR each byte\nkey: " + str(definition["xor_key"]) + "\n\n" + limit
    if kind == "memory":
        return "MEMORY WORKBENCH\nregion | offsets | initial\ninput buffer | 0..3 | 00 00 00 00\napproval marker | 4 | 00\npadding | 5..7 | 00 00 00\n\nMarker byte: 47 (hex). At most eight bytes exist in this isolated diagram. These are not host memory addresses.\n"
    if kind == "token":
        return "BUILD HISTORY\nold setting: RETENTION_TOKEN=retention-read-N47\ncurrent setting: RETENTION_TOKEN=(removed)\njob target: retention service\n\nRemoval from a file is not server-side revocation. Verify the actual permitted read.\n"
    return "SERVICE PLAN\nphotos: 443\nnotifications: 5050\nstaff sign-in: 22\n\nprecise_access = off\nretired_tokens_blocked = on\nbroad_bypass = off\n\nRestore scoped legitimate jobs. Do not restore retired authority or a broad bypass.\n"


def replace_role_and_secret(node, old_role, role, old_secret, secret):
    if isinstance(node, dict):
        return {(role if key == old_role else key): replace_role_and_secret(value, old_role, role, old_secret, secret)
                for key, value in node.items()}
    if isinstance(node, list):
        return [replace_role_and_secret(value, old_role, role, old_secret, secret) for value in node]
    if isinstance(node, str):
        if node == old_role:
            return role
        return node.replace(old_secret, secret).replace("ssh " + old_role + "@", "ssh " + role + "@")
    return node


def ensure_desk(host, role, group):
    host["files"]["/desk"] = entry("dir", owner=role, group=group, mode="750")


def add_observation_alternative(mission, primary, alternate_host, role):
    mid = mission["mission_id"]
    cid = mid.lower() + "_alternate"
    if cid in mission["challenges"]:
        return
    alternate = {
        "M05": ("trace", {"rows": [{"receipt": "C731", "owner": "Serin", "attachment": "exception-hold"}, {"receipt": "C730", "owner": "other", "attachment": "ordinary"}], "field": "receipt", "value": "C731"}, "receipt=C731"),
        "M11": ("compare", {"left": "download:/srv/public", "right": "resolved:/srv/private/marker.log"}, {"left": "download:/srv/public", "right": "resolved:/srv/private/marker.log"}),
        "M14": ("trace", {"rows": [{"request": "HOP14", "actor": "preview-worker", "target": "status-internal"}, {"request": "HOP13", "actor": "citizen", "target": "public"}], "field": "request", "value": "HOP14"}, "request=HOP14"),
        "M15": ("permission", {"host_id": alternate_host, "account_id": role, "group": "auditors"}, "auditors"),
        "M16": ("trace", {"rows": [{"permit": "ACL16", "group": "retention", "scope": "extra-read"}, {"permit": "ACL15", "group": "staff", "scope": "normal"}], "field": "permit", "value": "ACL16"}, "permit=ACL16"),
        "M22": ("path", {"base_path": "/jobs/archive", "target_path": "/handoff/control.key"}, "../../handoff/control.key"),
        "M24": ("trace", {"rows": [{"directive": "ECHO", "continuity": "services", "exclusion": "retention"}, {"directive": "ROUTINE", "continuity": "none", "exclusion": "none"}], "field": "directive", "value": "ECHO"}, "directive=ECHO"),
    }[mid]
    kind, fields, value = alternate
    mission["challenges"][cid] = {"kind": kind, **fields, "record_id": mid + "_RECORD", "source": "model:" + cid,
        "fact_id": mid.lower() + "_evidence", "requires_session": {"host_id": alternate_host, "account_id": role}}
    mission["records"][mid + "_RECORD"]["allowed_sources"].append("model:" + cid)
    ALTERNATIVES[mid] = alternate


def core_actions(actions, primary, alternate_host):
    kept, skip_password = [], False
    for action in actions:
        if action["kind"] == "password":
            if not skip_password:
                kept.append(action)
            skip_password = False
            continue
        if action["kind"] == "browse":
            continue
        if action["kind"] == "command":
            line = action["line"]
            if line.startswith("ssh "):
                destination = line.rsplit("@", 1)[-1]
                skip_password = destination in {primary + ".packet.test", alternate_host + ".packet.test"}
                if skip_password:
                    continue
            if line in {"cat /public/context.txt", "cat /public/route.txt", "cat /audit/signed.log", "scp /audit/signed.log ~/archive", "exit"}:
                continue
            if line == "cat /public/target.txt":
                action = command("cat /desk/target-handoff.note")
        kept.append(action)
    return kept


def strengthen_case(mission, solutions, row, ordinal):
    mid, primary = row[0], row[9]
    role, secret, alternate_role, alternate_secret, proof_host_a, proof_host_b = ACCESS[mid]
    alternate_host = "custody" + mid.lower()
    mission = replace_role_and_secret(mission, "auditor", alternate_role, "retain-" + mid.lower(), alternate_secret)
    solutions = replace_role_and_secret(solutions, "auditor", alternate_role, "retain-" + mid.lower(), alternate_secret)
    mission = replace_role_and_secret(mission, "analyst", role, "inspect-" + mid.lower(), secret)
    solutions = replace_role_and_secret(solutions, "analyst", role, "inspect-" + mid.lower(), secret)
    # Public handoff manifests are replaced with role-owned documents.
    for host_id, owner, group in [(primary, role, "staff"), (alternate_host, alternate_role, "auditors")]:
        host = mission["hosts"][host_id]
        ensure_desk(host, owner, group)
        for path in ["/public/context.txt", "/public/route.txt", "/audit/signed.log"]:
            host["files"].pop(path, None)
    if "/public/target.txt" in mission["hosts"][primary]["files"]:
        target_note = mission["hosts"][primary]["files"].pop("/public/target.txt")
        target_note["mode"] = "640"
        mission["hosts"][primary]["files"]["/desk/target-handoff.note"] = target_note
    for record in mission["records"].values():
        record["allowed_sources"] = [source for source in record["allowed_sources"] if not source.endswith(":/audit/signed.log")]
    if mid not in RECOVERY:
        add_observation_alternative(mission, primary, alternate_host, alternate_role)
    for challenge in mission["challenges"].values():
        challenge["name"] = "TOOL_" + challenge["kind"].upper() + "_NAME"
    main_id, alternate_id = mid.lower() + "_primary", mid.lower() + "_alternate"
    main = mission["challenges"][main_id]
    if mid == "M13":
        mission["hosts"][primary]["accounts"]["worker"] = {"password": "service-only", "groups": ["inspection"], "home": "/public"}
        main["host_id"] = primary
        main["run_as"] = "worker"
    visible_a = operational_rows(main["kind"], main)
    if mid == "M23":
        for child in ["m23_photo", "m23_session", "m23_login"]:
            definition = mission["challenges"][child]
            visible_a += "\n--- WORKFLOW OBSERVATION ---\n" + operational_rows(definition["kind"], definition)
    visible_b = operational_rows(mission["challenges"][alternate_id]["kind"], mission["challenges"][alternate_id]) if mid not in RECOVERY else "INDEPENDENT WORK LOG\n" + visible_a
    context_ko = f"[{AUTHORED[mid][0]}]\n\n업무 원장에서 관련 행을 찾으세요. 비슷한 이름·시각의 다른 사건을 같은 것으로 취급하지 마세요. 아래 식별값·요청·경로는 원자료 그대로입니다.\n\n{visible_a}"
    context_en = f"[{AUTHORED[mid][1]}]\n\nLocate the relevant entries in the work ledger. Do not conflate another event with a similar name or time. Identifiers, requests and paths below are retained as observed.\n\n{visible_a}"
    LOCALES["ko"][mid + "_CONTEXT"], LOCALES["en"][mid + "_CONTEXT"] = context_ko, context_en
    LOCALES["ko"][mid + "_HOST_NAME"] = row[2] + " 업무 서비스"
    LOCALES["en"][mid + "_HOST_NAME"] = primary.replace("-", " ").title() + " Work Service"
    LOCALES["ko"][mid + "_AUDIT_NAME"] = row[2] + " 독립 보관처"
    LOCALES["en"][mid + "_AUDIT_NAME"] = primary.replace("-", " ").title() + " Independent Custody"
    LOCALES["ko"][mid + "_ROUTE"] = "[별도 보관 담당자의 작업 메모]\n관측 원장은 현장 응답과 독립적으로 남겼습니다. 관련 업무 번호를 찾아 현재 사건의 원장과 대조하세요.\n\n" + visible_b
    LOCALES["en"][mid + "_ROUTE"] = "[Independent Custodian's Work Note]\nThis observation ledger was retained independently of the live response. Find the relevant business reference and compare it with the current case ledger.\n\n" + visible_b
    source_a = "/desk/" + {"M05": "receipts.csv", "M06": "signins.log", "M07": "shifts.log", "M08": "changes.http", "M09": "catalogue.log", "M10": "notice.txt", "M11": "downloads.log", "M12": "intake.csv", "M13": "jobs.log", "M14": "requests.log", "M15": "network.txt", "M16": "permissions.txt", "M17": "audit-bytes.txt", "M18": "build-history.conf", "M19": "capture.log", "M20": "clock-register.log", "M21": "portal.log", "M22": "relay.log", "M23": "workflows.conf", "M24": "directive.log"}.get(mid, "observations.log")
    source_b = "/desk/retained-" + source_a.rsplit("/", 1)[-1]
    mission["hosts"][primary]["files"][source_a] = entry(content=visible_a, owner=role, group="staff", mode="640", display_key=mid + "_CONTEXT")
    mission["hosts"][alternate_host]["files"][source_b] = entry(content=visible_b, owner=alternate_role, group="auditors", mode="640", display_key=mid + "_ROUTE")
    for page in mission["pages"].values():
        if page.get("body") == mid + "_BRIEF":
            page["body"] = mid + "_CONTEXT"
        if page.get("body") in {mid + "_CONTEXT", mid + "_ROUTE"} and not page.get("requires_session"):
            page["requires_session"] = {"host_id": primary, "account_id": role}
    root_url = "https://" + primary + ".packet.test"
    mission["pages"][root_url]["body"] = "COMMON_INDEX_TITLE"
    mission["pages"][root_url].pop("requires_session", None)
    mission["pages"][root_url]["links"].append({"label": "COMMON_WORKBENCH_TITLE", "url": root_url + "/workbench"})
    mission["pages"][root_url + "/login"]["body"] = "COMMON_LOGIN_TITLE"
    mission["pages"][root_url + "/login"].pop("requires_session", None)
    if mid == "M21":
        mission["pages"][root_url + "/receipts"] = {"title": "TOOL_IDOR_NAME", "body": mid + "_CONTEXT", "links": [],
            "host_id": primary, "challenge_id": "m21_receipt", "requires_session": {"host_id": primary, "account_id": role}}
        mission["pages"][root_url]["links"].append({"label": "TOOL_IDOR_NAME", "url": root_url + "/receipts"})
    if mid == "M23":
        for child, label in [("m23_photo", "TOOL_UPLOAD_NAME"), ("m23_session", "TOOL_SESSION_NAME"), ("m23_login", "TOOL_AUTH_NAME")]:
            mission["pages"][root_url]["links"].append({"label": label, "url": root_url + "/" + child})
    auth_block = f"\n\n[Case access]\n{role}@{primary}.packet.test / {secret}\n{alternate_role}@{alternate_host}.packet.test / {alternate_secret}\n"
    LOCALES["ko"][mid + "_BRIEF"] += "\n\n의뢰 범위 안의 읽기·검증 계정입니다. 자료를 읽는 권한이 결론까지 대신하지는 않습니다." + auth_block
    LOCALES["en"][mid + "_BRIEF"] += "\n\nThese are in-scope read and inspection accounts. Authority to read does not establish the conclusion." + auth_block
    # Preserve technical operations, but remove the repeated guest-to-secret recipe.
    a_core = core_actions(solutions["paths"][0]["actions"], primary, alternate_host)
    if mid in RECOVERY:
        b_core = [command("exit")] + [action for action in solutions["paths"][1]["actions"]
            if action["kind"] == "request" or (action["kind"] == "tool" and action["tool_id"] == mid.lower() + "_policy")]
    else:
        b_core = [tool(alternate_id, ALTERNATIVES[mid][2])]
        if mid == "M03":
            b_core.append(command("exit"))
        elif mid in {"M15", "M17", "M22"}:
            target, account, password = {"M15": ("management", "observer", "view-15"),
                "M17": ("proofvault", "reader", "lumen-17"), "M22": ("control", "maint", "inside-22")}[mid]
            b_core += login(target, account, password)
            b_core.append(command("cat /public/verify.txt"))
    proof_specs = PROOFS[mid]
    pre_count = 1 if len(proof_specs) <= 2 else 2
    proof_facts, proof_records, proof_paths_a, proof_paths_b = [], [], [], []
    proof_titles = []
    original_core_facts = [goal["id"] for goal in mission["goals"] if goal["kind"] == "fact"]
    for lane, host_id, account, password in [("A", proof_host_a, role, secret + "-desk"), ("B", proof_host_b, alternate_role, alternate_secret + "-desk")]:
        name = loc(f"{mid}_EVIDENCE_{lane}_HOST", "현장 관측 원장" if lane == "A" else "독립 보관 원장", "Field Observation Ledger" if lane == "A" else "Independent Custody Ledger")
        host = host_definition(host_id, 300 + ordinal * 2 + (lane == "B"), name, via=["local", primary, alternate_host])
        host["accounts"] = {account: {"password": password, "groups": ["case_readers"], "home": "/desk"}}
        host["files"] = {"/": entry("dir", owner=account, group="case_readers", mode="750"),
                         "/desk": entry("dir", owner=account, group="case_readers", mode="750")}
        mission["hosts"][host_id] = host
    for number, spec in enumerate(proof_specs, 1):
        title_ko, title_en, finding_ko, finding_en, left, right, reference = spec
        title_key = loc(f"{mid}_E{number}_TITLE", title_ko, title_en)
        proof_titles.append(title_key)
        rid, fact = f"{mid}_EXHIBIT_{number}", f"{mid.lower()}_exhibit_{number}"
        proof_records.append(rid)
        proof_facts.append(fact)
        previous = [] if number == 1 else [proof_facts[number - 2]]
        if number == pre_count + 1:
            previous = list(original_core_facts)
        document_a = f"REFERENCE {reference}\n\nFIELD DESK\n{left}\n\nHANDOFF TRANSCRIPT\n{right}\n\nOTHER ENTRY\nreference: OTHER-{reference}\nobservation: unrelated service job\n"
        rows = [{"reference": reference, "desk": "retained-witness", "observation": left + " / " + right},
                {"reference": "OTHER-" + reference, "desk": "other-job", "observation": "unrelated"}]
        document_b = "REFERENCE | DESK | OBSERVATION\n" + "\n".join(" | ".join(row.values()) for row in rows) + "\n"
        doc_a_key = loc(f"{mid}_E{number}_FIELD", f"[{title_ko} · 현장 원장]\n인계된 업무 번호에 해당하는 관측을 찾아 두 행을 대조하세요. 비슷한 다른 행을 섞으면 서로 다른 사건의 결론이 됩니다.\n\n{document_a}",
            f"[{title_en} · Field Ledger]\nFind the observations for the handed-over business reference and compare the two entries. Mixing a similar unrelated row would conflate different incidents.\n\n{document_a}")
        doc_b_key = loc(f"{mid}_E{number}_RETAINED", f"[{title_ko} · 독립 보관 원장]\n현장 응답의 사본이 아니라 별도 담당자가 보관한 관측 행입니다. 원장의 reference를 앞서 확인한 업무 번호와 연결하고 관련 행만 고르세요.\n\n{document_b}",
            f"[{title_en} · Independent Ledger]\nThese observations were retained by a separate desk rather than copied from the live response. Match reference to the earlier business identifier and select the relevant row only.\n\n{document_b}")
        exhibit_key = loc(f"{mid}_E{number}_FINDING", f"[{title_ko}]\n{finding_ko}\n\n근거 업무 번호: {reference}\n현장/보관 출처와 다음 관련 원장을 함께 보존합니다.",
            f"[{title_en}]\n{finding_en}\n\nBusiness reference: {reference}\nRetain the acquisition source and the next related ledger together.")
        canonical = f"BUSINESS-REFERENCE {reference}\nFIELD {left}\nRETAINED {right}\n"
        sources = []
        paths_for_proof = []
        for lane, host_id, account, password, text, display in [
            ("a", proof_host_a, role, secret + "-desk", document_a, doc_a_key),
            ("b", proof_host_b, alternate_role, alternate_secret + "-desk", document_b, doc_b_key)]:
            path = f"/desk/{reference.lower().replace(':','-')}.log"
            mission["hosts"][host_id]["files"][path] = entry(content=text, owner=account, group="case_readers", mode="640", display_key=display)
            cid = f"{mid.lower()}_exhibit_{number}_{lane}"
            source = "model:" + cid
            sources.append(source)
            definition = {"kind": "compare", "left": left, "right": right} if lane == "a" else {
                "kind": "packet" if mid in {"M19", "S02"} else "trace", "rows": rows, "field": "reference", "value": reference}
            definition.update({"name": title_key, "record_id": rid, "source": source,
                "fact_id": fact, "requires_facts": previous,
                "requires_session": {"host_id": host_id, "account_id": account}})
            mission["challenges"][cid] = definition
            input_value = {"left": left, "right": right} if lane == "a" else "reference=" + reference
            actions = login(host_id, account, password) + [command("cat " + path), tool(cid, input_value), command("exit")]
            paths_for_proof.append(actions)
        mission["records"][rid] = {"content": canonical, "display_content_key": exhibit_key, "allowed_sources": sources, "grants_facts": [fact]}
        mission["goals"] += [{"kind": "record_acquired", "record_id": rid}, {"kind": "fact", "id": fact}]
        proof_paths_a.append(paths_for_proof[0])
        proof_paths_b.append(paths_for_proof[1])
    for host_id, account in [(proof_host_a, role), (proof_host_b, alternate_role)]:
        mission["hosts"][host_id]["files"]["/desk/index.txt"] = entry(content="BUSINESS REFERENCE | LEDGER\n" + "\n".join(
            spec[6] + " | " + spec[6].lower().replace(":", "-") + ".log" for spec in proof_specs) + "\n",
            owner=account, group="case_readers", mode="640")
    prerequisite = proof_facts[pre_count - 1]
    # Both primary and alternate ways of producing the main evidence share the
    # same provenance prerequisites; no particular tool supplies the prerequisite.
    for cid, challenge in mission["challenges"].items():
        if "_exhibit_" not in cid:
            challenge["requires_facts"] = list(dict.fromkeys(challenge.get("requires_facts", []) + [prerequisite]))
    authority_note = (f"\n[Field ledger access]\n{role}@{proof_host_a}.packet.test / {secret}-desk\n"
                      f"[Independent ledger access]\n{alternate_role}@{proof_host_b}.packet.test / {alternate_secret}-desk\n"
                      "Read the ledger filenames for the business references named in the job.\n")
    LOCALES["ko"][mid + "_BRIEF"] += "\n추가로 확보할 독립 근거: " + ", ".join(spec[0] for spec in proof_specs) + authority_note
    LOCALES["en"][mid + "_BRIEF"] += "\nIndependent exhibits required: " + ", ".join(spec[1] for spec in proof_specs) + authority_note
    LOCALES["ko"][mid + "_GOAL"] += "\n추가 입증: " + " → ".join(spec[0] for spec in proof_specs)
    LOCALES["en"][mid + "_GOAL"] += "\nAdditional findings: " + " → ".join(spec[1] for spec in proof_specs)
    start_a = login(primary, role, secret) + [command("cat " + source_a)]
    start_b = login(primary, role, secret) + login(alternate_host, alternate_role, alternate_secret) + [command("cat " + source_b)]
    actions_a, actions_b = list(start_a), list(start_b)
    for index in range(pre_count):
        actions_a += proof_paths_a[index]
        actions_b += proof_paths_b[index]
    actions_a += a_core
    actions_b += b_core
    return_to_target = None
    if mid in {"M15", "M17", "M22"}:
        # Management/vault nodes have no direct edge to the observation desks.
        # Keep that boundary: return through the existing gateway, then verify
        # the target session again after collecting the final scoped evidence.
        actions_a.append(command("exit"))
        actions_b.append(command("exit"))
        return_to_target = {"M15": ("management", "observer", "view-15"),
                            "M17": ("proofvault", "reader", "lumen-17"),
                            "M22": ("control", "maint", "inside-22")}[mid]
    for index in range(pre_count, len(proof_specs)):
        actions_a += proof_paths_a[index]
        actions_b += proof_paths_b[index]
    if return_to_target:
        actions_a += login(*return_to_target)
        actions_b += login(*return_to_target)
    for path, actions in zip(solutions["paths"], [actions_a, actions_b]):
        path["actions"] = actions
        path["expected"]["archive_record_ids"] = list(dict.fromkeys(path["expected"]["archive_record_ids"] + proof_records))
        path["expected"]["facts"] = list(dict.fromkeys(path["expected"]["facts"] + proof_facts))
    # New goal payloads are stable operational records, not authoring manifests.
    target_id = mid + "_RECORD"
    target = mission["records"][target_id]
    target["content"] = f"NIGHT HANDOFF\n{row[-1]}\nRetention: original retained; necessary copy only.\n"
    for record in mission["records"].values():
        record["content"] = "\n".join(line for line in record["content"].splitlines()
            if not line.startswith(("CASE=", "RECORD="))) + "\n"
    for host in mission["hosts"].values():
        for file in host["files"].values():
            if file.get("record_id") in mission["records"]:
                file["content"] = mission["records"][file["record_id"]]["content"]
    for language in ["ko", "en"]:
        LOCALES[language][mid + "_AUDIT"] += "\n\n" + target["content"]
    stage_definitions = [("STAGE_BRIEF", mid + "_BRIEF"), ("STAGE_ENTRY", mid + "_CONTEXT")]
    stage_definitions += [(proof_titles[i], f"{mid}_E{i+1}_FIELD") for i in range(pre_count)]
    stage_definitions.append(("STAGE_TEST", mid + "_CONTEXT"))
    stage_definitions += [(proof_titles[i], f"{mid}_E{i+1}_FINDING") for i in range(pre_count, len(proof_specs))]
    stage_definitions.append(("STAGE_RESULT", mid + "_REPLY"))
    mission["milestones"] = [{"id": f"{mid.lower()}_stage_{index+1}", "title": title, "text": text}
        for index, (title, text) in enumerate(stage_definitions)]
    LOCALES["ko"][mid + "_HINT_1"] = "현재 부족한 근거와 그 업무 번호를 먼저 확인하세요. " + AUTHORED[mid][2]
    LOCALES["en"][mid + "_HINT_1"] = "First identify the missing exhibit and its business reference. " + AUTHORED[mid][3]
    LOCALES["ko"][mid + "_HINT_2"] = f"{proof_host_a}.packet.test의 현장 원장 또는 {proof_host_b}.packet.test의 독립 원장에서 같은 업무 번호를 찾으세요. 다음 단계는 앞 자료의 출처가 확인된 뒤 열립니다."
    LOCALES["en"][mid + "_HINT_2"] = f"Find the same business reference at {proof_host_a}.packet.test or in the independent ledger at {proof_host_b}.packet.test. The next stage opens after the preceding evidence is established."
    LOCALES["ko"][mid + "_HINT_3"] = "현장 원장의 두 관측을 대조하거나, 독립 원장에서 reference=업무번호로 관련 행을 좁히세요. 핵심 자료를 확보한 뒤에는 뒤에 붙은 해석·범위 자료도 확인해야 합니다."
    LOCALES["en"][mid + "_HINT_3"] = "Compare the two field observations, or filter the independent ledger with reference=the-business-reference. After the main evidence, establish its interpretation and scope as well."
    if mid == "M17":
        LOCALES["ko"]["M17_PRINCIPLE"] = "온라인 로그인 제한은 이미 복사된 검증 자료의 오프라인 추측을 막지 못합니다. 이 사건의 XOR는 주어진 허구 후보를 전달하기 위한 포장 모형이며 비밀번호 해시가 아닙니다. 실제 암호 감사 알고리즘이나 성능을 재현하지 않습니다."
        LOCALES["en"]["M17_PRINCIPLE"] = "Online sign-in limits do not prevent offline guessing against an already copied verifier. XOR here merely wraps a supplied fictional candidate; it is not a password hash. This case does not reproduce a real password-auditing algorithm or its performance."
        LOCALES["ko"]["M17_EXPLAIN"] += "\n" + LOCALES["ko"]["M17_PRINCIPLE"]
        LOCALES["en"]["M17_EXPLAIN"] += "\n" + LOCALES["en"]["M17_PRINCIPLE"]
    return mission, solutions


def build():
    common_strings()
    missions, fixtures = {}, {}
    for ordinal, row in enumerate(STORIES, 1):
        mission, solutions = make_m01(row) if row[0] == "M01" else make_case(row, ordinal)
        if row[0] != "M01":
            mission, solutions = strengthen_case(mission, solutions, row, ordinal)
        mid = row[0]
        if mid.startswith("M"):
            number = int(mid[1:])
            mission["prerequisites"] = [] if number == 1 else [f"M{number - 1:02}"]
        else:
            mission["prerequisites"] = [{"S01": "M08", "S02": "M20", "R01": "M16", "P01": "M16"}[mid]]
        mission["character_events"] = character_events(mid)
        decorate_goal_display(mission)
        missions[mid], fixtures[mid] = mission, solutions
    endings = [
        {"id": "sealed_audit", "title": loc("ENDING_SEALED_TITLE", "봉인된 감사 인계", "The Sealed Audit Handoff"),
         "text": loc("ENDING_SEALED_TEXT", "서윤은 인계 확인을, 도윤은 유지한 서비스의 범위를 남긴다. 태경은 긴급 승인과 감독 실패를 각각 서명하고 민서는 빠진 부분을 미확인으로 적는다. 기록은 봉인된 감사 인계로 넘어간다. 모든 시민이 오늘 밤의 일을 알지는 못하지만 원본과 이의 제기의 길은 남는다.", "Seoyun records the handoff; Doyun records which services he preserved. Taegyeong signs separately for emergency approval and oversight failure. Minseo marks the gaps as unknown. The evidence enters sealed audit custody. Not every citizen learns tonight's story, but the originals and a route to challenge the record remain."), "requires_facts": []},
        {"id": "public_redacted", "title": loc("ENDING_PUBLIC_TITLE", "시민을 가린 공개 기록", "A Public Record That Protects Citizens"),
         "text": loc("ENDING_PUBLIC_TEXT", "공지 원본과 재배포의 차이까지 확인한 자료를 바탕으로 개인 자료를 가린 사건 기록이 공개된다. 서윤의 서명도 도윤의 임시 중계도 빠지지 않는다. 사람들은 단순한 장애가 아니었음을 알게 되고, 남은 의문도 기록 옆에 남는다. 공개는 원본 파기나 모든 자료의 유출을 뜻하지 않는다.", "With the original notice distinguished from its republication, a redacted case record becomes public. Seoyun's signature and Doyun's temporary relay are both retained. People learn that this was more than an outage, with the remaining questions beside the evidence. Publication neither destroys originals nor dumps every record."), "requires_facts": ["m24_evidence", "s01_evidence", "s01_exhibit_2"]},
        {"id": "independent_review", "title": loc("ENDING_REVIEW_TITLE", "서로 검증할 수 있는 사본", "Copies That Can Check Each Other"),
         "text": loc("ENDING_REVIEW_TEXT", "독립 통신 기록과 작은 검증기·메모리 모형의 한계가 함께 보관된다. 민서는 한 도구의 성공을 전체 시스템의 안전으로 바꾸지 않는다. 서로 다른 보관 주체가 같은 사실을 검증할 수 있도록 최소 사본이 나뉜다. 마지막 화면에는 만능 열쇠 대신 출처와 남은 질문이 남는다.", "Independent transport evidence is retained alongside the limits of the small verifier and memory models. Minseo does not turn one tool's success into a claim about the entire system. Minimal copies go to separate custodians so they can check the same facts. The last screen holds provenance and open questions, not a universal key."), "requires_facts": ["m24_evidence", "s02_evidence", "r01_evidence", "p01_evidence", "s02_exhibit_2", "r01_exhibit_2", "p01_exhibit_2"]},
    ]
    campaign = {"schema_version": 1, "content_version": 1, "campaign_id": "midnight", "start_mission": "M01",
                "mission_order": list(missions), "missions": missions, "endings": endings}
    removed_keys = []
    for mid in missions:
        if mid == "M01":
            continue
        for number in range(1, 7):
            key = f"{mid}_STAGE_{number}"
            removed_keys.append(key)
            for strings in LOCALES.values():
                strings.pop(key, None)
    validate_authored_bundle(campaign, fixtures)
    OUT.mkdir(parents=True, exist_ok=True)
    write_json(OUT / "campaign.json", campaign)
    for locale, strings in LOCALES.items():
        write_json(OUT / "locales" / (locale + ".json"), strings)
    write_json(OUT / "locale_revision.json", {"revision": 2, "total_keys": len(LOCALES["en"]),
        "new_keys": [key for key in LOCALES["en"] if re.search(r"_E[1-4]_(TITLE|FIELD|RETAINED|FINDING)$", key) or "_EVIDENCE_" in key or key.startswith("TOOL_")],
        "changed_existing_keys": [mid + "_" + suffix for mid in missions if mid != "M01" for suffix in
            ["BRIEF", "CONTEXT", "ROUTE", "GOAL", "HINT_1", "HINT_2", "HINT_3", "HOST_NAME", "AUDIT_NAME", "AUDIT"]] + ["M17_PRINCIPLE", "M17_EXPLAIN"],
        "removed_unused_keys": removed_keys,
        "brief_note": "Authored story retained; role authorization and independent-exhibit annex appended. Preserve canonical observation rows."})
    write_json(ROOT / "godot/tests/fixtures/campaign_solutions.json", {"schema_version": 1, "missions": fixtures})
    report = {"missions": len(missions), "main": 24, "optional": 4, "routes": sum(len(x["paths"]) for x in fixtures.values()),
              "locale_keys": len(LOCALES["ko"]), "hosts": sum(len(x["hosts"]) for x in missions.values()),
              "required_records": sum(sum(goal["kind"] == "record_acquired" for goal in m["goals"]) for m in missions.values()),
              "independent_exhibits": sum(len(x) for x in PROOFS.values()),
              "action_counts": {mid: [len(path["actions"]) for path in case["paths"]] for mid, case in fixtures.items()},
              "model_kinds": sorted({c["kind"] for m in missions.values() for c in m["challenges"].values()}),
              "note": "Authored structure only; runtime solutions and playtime require integration checks."}
    write_json(OUT / "content_inventory.json", report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


def character_events(mid):
    return {
        "M01": [{"character_id": "C01", "state": "anonymous", "requires_choice": False}],
        "M02": [{"character_id": "C02", "state": "revealed", "requires_choice": False}],
        "M09": [{"character_id": "C03", "state": "anonymous", "requires_choice": False}],
        "M12": [{"character_id": "C01", "state": "revealed", "requires_choice": True, "choice_id": "meet_seoyun"}],
        "M15": [{"character_id": "C04", "state": "revealed", "requires_choice": False}],
        "M16": [{"character_id": "C03", "state": "revealed", "requires_choice": True, "choice_id": "meet_minseo"}],
        "M20": [{"character_id": "C04", "state": "accountability", "requires_choice": False}],
    }.get(mid, [])


def decorate_goal_display(mission):
    """Public labels/locations only; goal IDs and predicates remain authoritative."""
    mid = mission["mission_id"]

    def locations(record_id=None, fact_id=None, policy_id=None):
        result = []
        record_ids = [record_id] if record_id else []
        if fact_id:
            record_ids += [rid for rid, rec in mission["records"].items() if fact_id in rec.get("grants_facts", [])]
        for challenge in mission["challenges"].values():
            matches = ((record_id is not None and challenge.get("record_id") == record_id)
                or (fact_id is not None and (challenge.get("fact_id") == fact_id or challenge.get("record_id") in record_ids))
                or (policy_id is not None and challenge.get("policy_id") == policy_id))
            if not matches:
                continue
            session = challenge.get("requires_session", {})
            host_id = session.get("host_id", challenge.get("host_id", ""))
            if host_id in mission["hosts"]:
                domain = mission["hosts"][host_id]["domain"]
                result.append((session["account_id"] + "@" if session.get("account_id") else "") + domain)
        for rid in record_ids:
            for source in mission["records"].get(rid, {}).get("allowed_sources", []):
                host_id, separator, path = source.partition(":")
                if separator and host_id in mission["hosts"] and path.startswith("/"):
                    result.append(mission["hosts"][host_id]["domain"] + path)
            for url, page in mission["pages"].items():
                if page.get("record_id") == rid:
                    result.append(url)
        return " | ".join(dict.fromkeys(result)) or mission["initial_web_url"]

    for goal in mission["goals"]:
        kind = goal["kind"]
        if kind == "sources_preserved":
            continue
        label = mid + "_TITLE"
        target = mission["initial_web_url"]
        if kind == "record_acquired":
            record_id = goal["record_id"]
            match = re.fullmatch(re.escape(mid) + r"_EXHIBIT_([1-4])", record_id)
            if match:
                label = f"{mid}_E{match[1]}_TITLE"
            target = locations(record_id=record_id)
        elif kind == "fact":
            fact = goal["id"]
            match = re.fullmatch(re.escape(mid.lower()) + r"_exhibit_([1-4])", fact)
            if match:
                label = f"{mid}_E{match[1]}_TITLE"
            else:
                label = {
                    "M06": "TOOL_AUTH_NAME", "M07": "TOOL_SESSION_NAME", "M08": "TOOL_CSRF_NAME", "M12": "TOOL_UPLOAD_NAME",
                    "M23": {"m23_normal_photo": "TOOL_UPLOAD_NAME", "m23_retired_blocked": "M23_E2_TITLE",
                            "m23_normal_login": "TOOL_AUTH_NAME", "m23_evidence": "M23_E3_TITLE"}.get(fact, "M23_TITLE"),
                }.get(mid, mid + "_TITLE")
            target = locations(fact_id=fact)
        elif kind == "policy":
            label = {"M06": "TOOL_AUTH_NAME", "M07": "TOOL_SESSION_NAME", "M08": "TOOL_CSRF_NAME", "M12": "TOOL_UPLOAD_NAME",
                     "M23": "M23_E3_TITLE" if goal["id"] == "precise_access" else "M23_E2_TITLE"}.get(mid, "TOOL_POLICY_NAME")
            target = locations(policy_id=goal["id"])
        elif kind == "session":
            host = mission["hosts"][goal["host_id"]]
            label = "TOOL_SESSION_NAME"
            target = goal["account_id"] + "@" + host["domain"] + ":22"
        elif kind == "service":
            host = mission["hosts"][goal["host_id"]]
            service = host["services"][str(goal["port"])]
            label = host["name"]
            target = host["domain"] + ":" + str(goal["port"]) + " (" + service["protocol"] + ")"
        assert label in LOCALES["ko"] and label in LOCALES["en"], (mid, label)
        goal["label_display"] = label
        goal["target_display"] = target


def validate_authored_bundle(campaign, fixtures):
    expected = [f"M{i:02}" for i in range(1, 25)] + ["S01", "S02", "R01", "P01"]
    assert campaign["mission_order"] == expected
    assert set(LOCALES["ko"]) == set(LOCALES["en"])
    for mid, mission in campaign["missions"].items():
        assert 5 <= len(mission["milestones"]) <= 12, mid
        assert len(fixtures[mid]["paths"]) == 2, mid
        for challenge in mission["challenges"].values():
            record = mission["records"][challenge["record_id"]]
            assert challenge["source"] in record["allowed_sources"], (mid, challenge)
        for host in mission["hosts"].values():
            for path, file in host["files"].items():
                if path != "/":
                    assert str(Path(path).parent) in host["files"], (mid, path)
                if file.get("record_id") in mission["records"]:
                    record = mission["records"][file["record_id"]]
                    assert file["content"] == record["content"], (mid, path)
        for path in fixtures[mid]["paths"]:
            assert len(path["actions"]) >= 5 and path["expected"]["completed"] is True, (mid, path["id"])
            stack, pending = ["local"], None
            for action in path["actions"]:
                if action["kind"] == "command" and action["line"].startswith("ssh "):
                    user, domain = action["line"][4:].split("@", 1)
                    matches = [(hid, host) for hid, host in mission["hosts"].items() if host["domain"] == domain]
                    assert len(matches) == 1, (mid, path["id"], domain)
                    hid, host = matches[0]
                    assert user in host["accounts"], (mid, path["id"], user)
                    assert stack[-1] == hid or stack[-1] in host.get("via", ["local"]), (mid, path["id"], "missing declared route", stack[-1], hid)
                    pending = hid
                elif action["kind"] == "password":
                    assert pending, (mid, path["id"], "unexpected password")
                    stack.append(pending)
                    pending = None
                elif action["kind"] == "command" and action["line"] == "exit":
                    assert len(stack) > 1, (mid, path["id"], "extra exit")
                    stack.pop()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    build()
