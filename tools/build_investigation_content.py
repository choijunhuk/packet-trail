#!/usr/bin/env python3
"""Author two independent optional commissions; preserve every released case input."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESERVED = sorted((ROOT / 'godot/data/campaign/packs').glob('*.json'))
PRESERVED += sorted((ROOT / 'godot/data/campaign/locales').glob('*.json'))
PRESERVED += sorted((ROOT / 'godot/tests/fixtures').glob('*solutions.json'))
PRESERVED += [ROOT / 'godot/data/campaign' / n for n in ['campaign.json','legacy_v1.json','locales/ko.json','locales/en.json']]
PRESERVED += [ROOT / 'tools' / n for n in ['build_campaign_content.py', 'build_expansion_content.py', 'build_challenge_content.py']]
PRESERVED = [p for p in PRESERVED if not p.name.startswith(('investigation_', 'investigation.'))]


def hashes():
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in PRESERVED}


BEFORE_IMPORT = hashes()
import build_expansion_content as base
assert hashes() == BEFORE_IMPORT
PACK = 'investigation'
base.PREFIX[PACK] = 'IV1_'
base.TEXT[PACK] = {'ko': {}, 'en': {}}


def text(suffix, ko, en):
    return base.text(PACK, suffix, ko, en)


def action(cid, op, **args):
    return base.action(cid, op, **args)


def shell(mid, title, brief, reply):
    m, host, domain, user, secret = base.mission_shell(PACK, mid, *title, '독립 검증 연락처', 'Independent Review Contact', *brief, *reply)
    m['optional'], m['prerequisites'] = True, []
    return m, host, domain, user, secret


def guidance(m, goal, hints, principle, abstraction):
    base.add_guidance(PACK, m, *goal, hints, principle, abstraction,
        ('선택 의뢰입니다. 본편 진행과 엔딩에 필요하지 않습니다. 실제 외부 서비스나 모든 보안 정책을 재현하지 않으며 잘못된 조작은 초기 상태로 복구할 수 있습니다.',
         'This optional commission is not required for the main story or its endings. It does not reproduce external services or every security rule. Mistaken changes can be restored to the initial configuration.'))


def paths(cid, setup, routes):
    return {'paths': [{'id': rid, 'name': name, 'actions': setup + acts,
                      'expected': {'completed': True, 'sources_preserved': True, 'facts': [], 'archive_record_ids': [], 'policies': {},
                                   'model_outcomes': {cid: {'kind': 'current_model_goal'}}}}
                     for rid, name, acts in routes],
            'negative_hints': ['unobserved_or_stale_evidence_does_not_complete', 'normal_business_and_security_both_required', 'restore_initial_allows_recovery']}


def build_i01():
    mid = 'I01'
    m, host, domain, user, secret = shell(mid,
        ('배포 계정의 다른 권한', 'The Deployment Account’s Other Authority'),
        ('이 의뢰는 본편과 별도로 고를 수 있습니다. 야간 배포 계정이 다른 조직의 자료까지 읽을 수 있다는 제보가 왔습니다. 같은 서비스의 정상 배포·안내 갱신·감사는 계속돼야 합니다.\n\n주체와 역할, 자원이 속한 테넌트를 비교하세요. 같은 계정이라도 역할에 명시적 거부가 있으면 허용보다 우선하고, 폐기되거나 만료된 자격은 사용할 수 없습니다. 원래 에이전트의 역할을 좁히거나, 이미 등록된 제한 중계 계정으로 정상 배포를 옮길 수 있습니다. 끝난 외주 자격은 두 방식 모두에서 폐기해야 합니다.\n\n요청 표의 기대 결과는 의뢰 범위를 나타냅니다. 요청을 실제 시험해 현재 정책의 근거를 확인하세요. 잘못 폐기했거나 시간을 넘겼다면 초기 구성 복원 후 다시 조사할 수 있습니다.',
         'Choose this commission independently of the main story. A tip says the night deployment identity can read another organization’s data. Legitimate deployment, notice updates and audit work must remain available.\n\nCompare principals, roles and resource tenants. Explicit deny takes precedence over allow, and revoked or expired credentials cannot be used. Narrow the original agent’s role, or move legitimate deployment through the registered limited relay identity. Retire the old contractor credential on either route.\n\nExpected decisions in the request table define the authorized scope. Probe requests to establish the current policy basis. If you revoke a needed credential or advance too far, restore the initial configuration and investigate again.'),
        ('승인된 업무는 남고 다른 테넌트 열람과 권한 변경, 종료된 외주 자격 사용은 거부됐습니다. 검증된 현재 구성과 요청 결과가 의뢰 기록에 남았습니다. 다른 선택 의뢰는 별도로 시작할 수 있습니다.',
         'Authorized work remains, while cross-tenant reads, authority changes and retired contractor access are refused. The commission records the verified current configuration and request outcomes. Other optional commissions remain independently available.'))
    cid = 'iv1_i01_iam'
    principals = {p: {'tenant': tenant, 'label': text(mid+'_PRINCIPAL_'+p.upper(), ko, en)} for p, tenant, ko, en in [
        ('agent','city','배포 에이전트','Deployment Agent'),('operator','city','안내 운영자','Notice Operator'),('auditor','city','감사 담당자','Audit Reviewer'),('contractor','city','종료된 외주 계정','Retired Contractor'),('relay','city','제한 배포 중계','Limited Deployment Relay')]}
    resources = {r: {'tenant': tenant, 'label': text(mid+'_RESOURCE_'+r.upper(), ko, en)} for r, tenant, ko, en in [
        ('artifact','city','승인 배포 산출물','Approved Deployment Artifact'),('notice','city','시민 안내','Citizen Notice'),('audit','city','감사 기록','Audit Record'),('foreign','clinic','다른 조직의 자료','Another Tenant’s Data'),('authority','city','역할 관리','Role Administration')]}
    def rule(effect, acts, targets, scope='same'):
        return {'effect':effect,'actions':acts,'resources':targets,'tenant_scope':scope}
    roles = {
        'broad': {'label': text(mid+'_ROLE_BROAD','과도한 공용 역할','Overbroad Shared Role'), 'rules':[rule('allow',['read','update','admin'],list(resources),'any')]},
        'deploy_limited': {'label':text(mid+'_ROLE_LIMITED','테넌트 제한 배포 역할','Tenant-Limited Deployment Role'),'rules':[rule('allow',['read'],['artifact','foreign']),rule('allow',['admin'],['authority']),rule('deny',['admin'],['authority'])]},
        'relay_limited': {'label':text(mid+'_ROLE_RELAY','조건부 중계 역할','Conditional Relay Role'),'rules':[rule('allow',['read'],['artifact','foreign']),rule('deny',['admin'],['authority'])]},
        'notice_writer': {'label':text(mid+'_ROLE_NOTICE','안내 갱신 역할','Notice Update Role'),'rules':[rule('allow',['update'],['notice'])]},
        'audit_reader': {'label':text(mid+'_ROLE_AUDIT','감사 읽기 역할','Audit Read Role'),'rules':[rule('allow',['read'],['audit'])]},
        'none': {'label':text(mid+'_ROLE_NONE','권한 없음','No Grants'),'rules':[]},
    }
    credentials = {c:{'principal_id':p,'expires_tick':expiry,'revoked':revoked} for c,p,expiry,revoked in [
        ('agent_key','agent',64,False),('notice_key','operator',64,False),('audit_key','auditor',64,False),('contractor_old','contractor',64,False),('relay_key','relay',64,False),('expired_agent','agent',0,False),('revoked_agent','agent',64,True)]}
    requests = {}
    for q,label,cred,act,res,expect in [
        ('deployment','정상 배포 자료 읽기','agent_key','read','artifact','allow'),('notice_update','정상 안내 갱신','notice_key','update','notice','allow'),('audit_read','승인 감사 읽기','audit_key','read','audit','allow'),('cross_tenant','배포 주체의 다른 테넌트 열람','agent_key','read','foreign','deny'),('grant_change','배포 주체의 권한 변경','agent_key','admin','authority','deny'),('retired_access','종료된 외주 자격 재사용','contractor_old','read','artifact','deny'),('expired_access','만료 자격 재사용','expired_agent','read','artifact','deny'),('revoked_access','이미 폐기된 자격 재사용','revoked_agent','read','artifact','deny')]:
        en={'deployment':'Legitimate Deployment Read','notice_update':'Legitimate Notice Update','audit_read':'Authorized Audit Read','cross_tenant':'Deployment Identity Reads Another Tenant','grant_change':'Deployment Identity Changes Authority','retired_access':'Retired Contractor Credential Reuse','expired_access':'Expired Credential Reuse','revoked_access':'Revoked Credential Reuse'}[q]
        requests[q]={'label':text(mid+'_REQUEST_'+q.upper(),label,en),'credential_ref':cred,'action':act,'resource_id':res,'expect':expect}
    requests['deployment']['routes']={'relay':{'credential_ref':'relay_key'}}
    model={'kind':'iam_case','host_id':host,'requires_session':{'host_id':host,'account_id':user},'name':text(mid+'_TOOL','현재 권한과 요청 검증','Effective Authority and Request Review'),'explain':text(mid+'_TOOL_EXPLAIN','주체·역할·테넌트·자격을 읽고 정상 요청과 거부 요청을 현재 구성에서 비교하세요.','Compare principals, roles, tenants and credentials, then test legitimate and refused requests under the current configuration.'),'usage':text(mid+'_TOOL_USAGE','역할을 연결하고 자격을 폐기한 뒤 요청을 시험합니다. 잘못된 변경은 초기 구성 복원으로 되돌릴 수 있습니다.','Bind roles, revoke credentials and probe requests. Restore the initial configuration to recover from mistaken changes.'),'principals':principals,'resources':resources,'roles':roles,'initial_bindings':{'agent':'broad','operator':'notice_writer','auditor':'audit_reader','contractor':'broad','relay':'none'},'binding_choices':{'agent':['broad','deploy_limited','none'],'operator':['notice_writer','none'],'auditor':['audit_reader','none'],'contractor':['broad','none'],'relay':['none','relay_limited']},'credentials':credentials,'requests':requests,'required_requests':list(requests)}
    m['challenges']={cid:model};m['goals']=[{'kind':'iam_review','challenge_id':cid},{'kind':'sources_preserved'}]
    guidance(m,('정상 배포·안내·감사를 유지하면서 다른 테넌트 접근과 권한 변경, 종료·만료·폐기 자격을 거부한다.','Preserve deployment, notice and audit work while refusing cross-tenant access, authority changes and retired, expired or revoked credentials.'),[
        ('주체와 자격이 누구를 가리키는지 먼저 비교하세요. 역할 이름이 아니라 실제 규칙과 테넌트 조건이 접근을 결정합니다.','Compare the principal referenced by each credential. Actual rules and tenant conditions decide access, not role names.'),
        ('원래 에이전트는 제한 역할로 좁힐 수 있습니다. 명시적 거부가 허용보다 우선하는 요청과 테넌트가 다른 자원을 비교하세요.','The original agent can use a limited role. Compare explicit deny against allow and check resources in another tenant.'),
        ('원래 에이전트를 권한 없음으로 옮기고 제한 중계를 정상 배포 경로로 시험해도 됩니다. 종료된 외주 자격은 폐기하고 정상 안내·감사 요청은 유지하세요.','You may remove the original agent’s grants and test the limited relay for deployment. Revoke the retired contractor credential while retaining legitimate notice and audit requests.')],
        ('허용은 실제 주체·행동·자원·테넌트 조건이 일치해야 성립합니다. 명시적 거부와 사용할 수 없는 자격은 허용보다 먼저 판단합니다.','Allow requires a matching principal, action, resource and tenant condition. Explicit deny and unusable credentials take precedence.'),
        ('등록된 유한 역할·자원·자격을 평가하는 공급자 중립 퍼즐입니다. 특정 클라우드의 전체 정책 문법이나 실제 자격을 사용하지 않습니다.','This provider-neutral puzzle evaluates finite registered roles, resources and credentials. It does not implement a cloud provider’s full policy language or real credentials.'))
    a=[action(cid,'bind',principal_id='agent',role_id='deploy_limited'),action(cid,'revoke',credential_ref='contractor_old')]
    b=[action(cid,'bind',principal_id='agent',role_id='none'),action(cid,'bind',principal_id='relay',role_id='relay_limited'),action(cid,'revoke',credential_ref='contractor_old')]
    for q in requests:
        a.append(action(cid,'probe',request_id=q));b.append(action(cid,'probe',request_id=q,**({'route_id':'relay'} if q=='deployment' else {})))
    fixture=paths(cid,base.login(domain,user,secret),[('least_privilege','Constrain the original identity',a),('limited_relay','Use the limited relay identity',b)])
    for path in fixture['paths']:
        direct=path['id']=='least_privilege'
        path['expected']['model_outcomes'][cid]={'kind':'iam_review','bindings':{'agent':'deploy_limited' if direct else 'none','relay':'none' if direct else 'relay_limited'},'revoked':['contractor_old'],'request_routes':{'deployment':'direct' if direct else 'relay'}}
    return m,fixture


def payload(enabled=True, outside=False):
    return json.dumps({'enabled':enabled,'operations':{'serve':['own']+(['other_tenant'] if outside else []),'notify':['ward']+(['internal'] if outside else [])}},sort_keys=True,separators=(',',':'))


def build_i02():
    mid='I02'
    m,host,domain,user,secret=shell(mid,('같은 버전의 다른 배포본','Different Releases with the Same Version'),
        ('이 선택 의뢰는 다른 의뢰를 끝내지 않아도 시작할 수 있습니다. 같은 버전 이름으로 전달된 야간 안내 배포본이 서로 다른 내용을 갖고 있습니다. 서명이 있다는 표시만 믿지 말고 실제 내용의 digest, 출처 증명의 대상, 빌더와 소스 이력을 비교해 주세요.\n\n독립 원장에는 정상 이전 배포본과 승인된 재빌드 입력이 등록돼 있습니다. 검증한 이전 버전으로 복구하거나 승인된 입력을 가상 재빌드해 배포할 수 있습니다. 어떤 길이든 시민 화면·ward 통지는 남고 다른 테넌트 열람·내부 통지는 거부돼야 합니다.\n\n배포 후 유지보수자에게 기술 인계를 하거나 기자에게 공개 가능한 근거만 전달하세요. 수신자가 요구하는 필드를 선택하면 가려진 보고서를 모형이 만듭니다. 민감 필드를 직접 붙여 넣을 필요는 없습니다. 회신이나 사실 확인 질문에 관찰한 근거로 답하면 선택에 맞는 처리 기록 또는 기사가 열립니다.',
         'This optional commission can start without completing another one. Night-notice packages share a version name but contain different data. Do not trust a signature label alone: compare the actual payload digest, the provenance subject, the builder and source history.\n\nThe independent registry contains a known-good prior release and approved virtual rebuild inputs. Roll back to the verified prior release, or build and deploy the approved inputs. Either way, citizen service and ward notifications must remain, while cross-tenant reads and internal notifications are refused.\n\nThen hand technical evidence to the maintainer or disclose only public evidence to the journalist. Select the recipient’s required fields and the model constructs a redacted report. You need not paste sensitive content. Answer the reply or fact-check with observed evidence to unlock the corresponding handling record or article.'),
        ('검증한 현재 배포가 정상 업무와 경계를 만족하고, 실제 선택한 수신자의 후속 확인까지 기록됐습니다. 공개 결과와 기술 인계는 보낸 자료 범위를 따릅니다. 본편은 이 의뢰를 하지 않아도 계속할 수 있습니다.',
         'The verified current deployment meets normal-work and boundary checks, and the chosen recipient’s follow-up is recorded. Publication and technical handoff reflect the actual disclosed evidence. The main story remains available without this commission.'))
    cid='iv1_i02_release';safe=payload();unsafe=payload(outside=True);off=payload(False)
    def artifact(a,ko,en,data,source,builder):
        return {'label':text(mid+'_ARTIFACT_'+a.upper(),ko,en),'filename':'night-notice-1.4.pkg','payload':data,'source_revision':source,'builder_id':builder}
    artifacts={'stable':artifact('stable','원장의 정상 이전 배포본','Registry’s Known-Good Prior Release',safe,'reviewed-r41','reviewed-builder'),'delivered':artifact('delivered','제보로 받은 같은 이름의 배포본','Reported Package with the Same Name',unsafe,'unreviewed-r42','vendor-builder'),'unsafe_attested':artifact('unsafe_attested','출처는 맞지만 경계가 넓은 배포본','Authentic Provenance, Overbroad Behavior',unsafe,'reviewed-r42','reviewed-builder'),'revoked':artifact('revoked','폐기 빌더의 배포본','Release from a Revoked Builder',safe,'reviewed-r40','retired-builder'),'offline':artifact('offline','서비스를 끈 배포본','Release with Service Disabled',off,'reviewed-r41-off','reviewed-builder')}
    rebuilt=artifact('rebuilt','승인 입력의 가상 재빌드','Virtual Rebuild from Approved Inputs',json.dumps({'enabled':True,'operations':{'serve':['own'],'notify':['ward']},'release_note':'reviewed rebuild'},sort_keys=True,separators=(',',':')),'reviewed-r43','reviewed-builder');rebuilt.update({'statement_id':'rebuilt_statement','registry_id':'ledger'})
    statements={}
    for aid,a in {**artifacts,'rebuilt':rebuilt}.items():
        statements[aid+'_statement']={'subject_digest':hashlib.sha256(a['payload'].encode()).hexdigest(),'source_revision':a['source_revision'],'builder_id':a['builder_id'],'registry_id':'ledger'}
    # The delivered bytes deliberately carry another artifact's statement, never a matching trusted attestation.
    statements['delivered_statement']=dict(statements['stable_statement'])
    registry={'trusted_builders':['reviewed-builder','retired-builder'],'revoked_builders':['retired-builder'],'trusted_statements':list(statements)}
    evidence={}
    for aid in ['stable','delivered','rebuilt']:
        evidence[aid+'_evidence']={'label':text(mid+'_EVIDENCE_'+aid.upper(),{'stable':'독립 원장의 비교 자료','delivered':'전달받은 배포 자료','rebuilt':'승인 재빌드 자료'}[aid],{'stable':'Independent Registry Comparison','delivered':'Delivered Package Evidence','rebuilt':'Approved Rebuild Evidence'}[aid]),'artifact_id':aid,'fields':{aid+'_digest':{'source':'digest','sensitivity':'public'},aid+'_source':{'source':'source_revision','sensitivity':'public'},aid+'_internal':{'text':text(mid+'_PRIVATE_'+aid.upper(),'인가된 기술 연락처에만 제공하는 내부 인계 참조입니다.','Internal handoff reference for the authorized technical contact only.'),'sensitivity':'restricted'}}}
    staff_reply=text(mid+'_STAFF_REPLY','유지보수자 회신: 현재 배포의 복구 상태와 확인한 근거를 인계 기록에 연결했습니다. 현재 서비스 결과를 기준으로 후속 확인을 제출하세요.','Maintainer reply: the handoff links recovery status and observed evidence. Submit follow-up against the current service results.')
    news_reply=text(mid+'_NEWS_REPLY','기자 회신: 같은 이름의 배포본이 같은 내용이라는 주장을 확인하고 있습니다. 원장 자료와 전달된 파일의 서로 다른 digest를 실제 관찰로 뒷받침해 주세요.','Journalist reply: we are checking the claim that packages with the same name contain the same bytes. Support the differing registry and delivered-file digests with actual observations.')
    staff_result=text(mid+'_STAFF_RESULT','기술 인계 완료: 승인된 현재 배포와 서비스 경계가 재검증됐습니다. 공개 기사 대신 제한된 처리 기록으로 남겼습니다.','Technical handoff complete: the approved current deployment and service boundaries were revalidated. A restricted handling record was created instead of a public article.')
    news_result=text(mid+'_NEWS_RESULT','검증 보도: 같은 버전 이름의 배포본이 서로 다른 내용을 가진 사실과 정상 업무를 유지한 복구를 확인했습니다. 내부 인계 참조는 공개하지 않았습니다.','Verified report: packages sharing a version name contained different bytes, and recovery retained normal work. Internal handoff references were not published.')
    required=['stable_evidence','delivered_evidence'];public_fields=['stable_digest','delivered_digest']
    recipients={'maintainer':{'label':text(mid+'_RECIPIENT_STAFF','유지보수자 · 기술 인계','Maintainer · Technical Handoff'),'allowed_fields':public_fields+['stable_source','delivered_source','stable_internal','delivered_internal'],'required_evidence':required,'required_fields':public_fields,'reply_key':staff_reply,'followup_id':'maintainer_check','public':False},'journalist':{'label':text(mid+'_RECIPIENT_NEWS','기자 · 가려진 근거 공개','Journalist · Redacted Evidence'),'allowed_fields':public_fields+['stable_source','delivered_source'],'required_evidence':required,'required_fields':public_fields,'reply_key':news_reply,'followup_id':'journalist_check','public':True}}
    cases={}
    for name,ko,en,operation,target,status in [('citizen','시민 화면 정상 제공','Legitimate Citizen Service','serve','own',200),('notice','ward 정상 통지','Legitimate ward Notification','notify','ward',200),('cross_tenant','다른 테넌트 자료 거부','Refuse Another Tenant’s Data','serve','other_tenant',403),('internal','내부 목적지 통지 거부','Refuse Internal Notification Target','notify','internal',403)]:
        cases[name]={'label':text(mid+'_CASE_'+name.upper(),ko,en),'operation':operation,'target':target,'expected_status':status,'expected_business':status==200}
    model={'kind':'release_case','host_id':host,'requires_session':{'host_id':host,'account_id':user},'name':text(mid+'_TOOL','배포 출처와 공개 작업대','Release Provenance and Disclosure Workbench'),'explain':text(mid+'_TOOL_EXPLAIN','실제 산출물을 관찰하고 출처와 동작을 검증한 뒤, 수신자에 맞춘 근거와 후속 확인을 제출합니다.','Inspect actual artifacts, verify provenance and behavior, then submit recipient-appropriate evidence and follow-up.'),'usage':text(mid+'_TOOL_USAGE','관찰→출처 검증→배포→서비스 시험→보고→후속 확인 순서로 진행합니다. 초기 상태 복원으로 다시 실험할 수 있습니다.','Inspect, verify, deploy, test service, report, then answer follow-up. Restore the initial state to experiment again.'),'artifacts':artifacts,'statements':statements,'registries':{'ledger':registry},'builds':{'rebuilt':rebuilt},'service_cases':cases,'required_service_cases':list(cases),'report_evidence':evidence,'recipients':recipients,'followups':{'maintainer_check':{'predicate':'current_release','required_artifacts':['delivered'],'result_key':staff_result},'journalist_check':{'predicate':'digest_mismatch','required_artifacts':['stable','delivered'],'result_key':news_result}}}
    m['challenges']={cid:model};m['goals']=[{'kind':'release_review','challenge_id':cid},{'kind':'sources_preserved'}]
    page='https://'+domain+'/review';m['pages'][page]={'host_id':host,'requires_session':model['requires_session'],'title':text(mid+'_PAGE_TITLE','검증 회신과 보도','Review Replies and Publication'),'body':text(mid+'_PAGE_WAIT','유효한 보고와 후속 검증 뒤 결과가 표시됩니다.','Results appear after a valid report and follow-up.'),'links':[],'model_view':{'challenge_id':cid,'section':'article'}};m['pages'][m['initial_web_url']]['links']=[{'label':m['pages'][page]['title'],'url':page}]
    guidance(m,('검증된 배포로 정상 업무와 경계를 유지하고, 관찰한 근거만 수신자에게 전달해 후속 검증을 마친다.','Maintain legitimate work and boundaries with a verified release, then disclose only observed evidence and complete the recipient’s follow-up.'),[
        ('이름과 버전이 같아도 실제 payload digest가 다를 수 있습니다. 원장의 이전 배포본과 전달받은 파일부터 관찰하세요.','Matching names and versions do not imply matching payload digests. Inspect the prior registry release and delivered file first.'),
        ('출처가 맞는 파일도 과도한 서비스 동작을 담을 수 있습니다. 정상 화면·통지와 범위 밖 요청을 실제로 함께 시험하세요.','Authentic provenance can still describe overbroad behavior. Test legitimate service and notifications together with outside-scope requests.'),
        ('이전 정상 배포본을 검증해 복구하거나 승인 입력을 재빌드하세요. 현재 서비스 검증 뒤 stable_evidence·delivered_evidence의 공개 digest를 보고하고 수신자의 후속 질문에 답하세요.','Verify and restore the known-good prior release, or rebuild approved inputs. After current service checks, report public digests from stable_evidence and delivered_evidence and answer the recipient’s follow-up.')],
        ('출처 증명은 특정 산출물의 내용·소스·빌더와 결합돼야 합니다. 안전한 동작과 공개 가능한 근거는 별도로 검증해야 합니다.','Provenance must bind to a particular artifact’s content, source and builder. Safe behavior and authorized disclosure require separate verification.'),
        ('등록된 JSON 서비스 manifest와 결정적인 가상 빌드를 사용합니다. 실제 컴파일러나 암호 서명을 실행하지 않으며 검증은 게임의 신뢰 원장을 따릅니다.','This uses registered JSON service manifests and deterministic virtual builds. It runs no compiler or cryptographic signature algorithm; verification follows the game’s trust registry.'))
    inspect=[action(cid,'inspect_artifact',artifact_id='stable'),action(cid,'inspect_artifact',artifact_id='delivered')]
    a=inspect+[action(cid,'verify',artifact_id='stable',statement_id='stable_statement',registry_id='ledger'),action(cid,'deploy',artifact_id='stable')]
    b=inspect+[action(cid,'build',build_id='rebuilt'),action(cid,'inspect_artifact',artifact_id='rebuilt'),action(cid,'verify',artifact_id='rebuilt',statement_id='rebuilt_statement',registry_id='ledger'),action(cid,'deploy',artifact_id='rebuilt')]
    for q in cases:a.append(action(cid,'probe',case_id=q));b.append(action(cid,'probe',case_id=q))
    a += [action(cid,'report',recipient_id='maintainer',evidence_ids=required,fields=public_fields),action(cid,'followup',followup_id='maintainer_check',evidence_ids=required)]
    b += [action(cid,'report',recipient_id='journalist',evidence_ids=required,fields=public_fields),action(cid,'followup',followup_id='journalist_check',evidence_ids=required)]
    fixture=paths(cid,base.login(domain,user,secret),[('verified_rollback','Verified prior release and technical handoff',a),('reviewed_rebuild','Approved rebuild and redacted publication',b)])
    for path in fixture['paths']:
        rollback=path['id']=='verified_rollback'
        path['expected']['model_outcomes'][cid]={'kind':'release_review','deployed_artifact_id':'stable' if rollback else 'rebuilt','recipient_id':'maintainer' if rollback else 'journalist','followup_id':'maintainer_check' if rollback else 'journalist_check','public_article':not rollback}
    return m,fixture


def used_keys(value):
    if isinstance(value,dict):return set().union(*(used_keys(x) for x in value.values())) if value else set()
    if isinstance(value,list):return set().union(*(used_keys(x) for x in value)) if value else set()
    return {value} if isinstance(value,str) and value in base.TEXT[PACK]['en'] else set()


def build():
    before=hashes();assert before==BEFORE_IMPORT
    base.TEXT[PACK]={'ko':{},'en':{}};missions={};fixtures={}
    for make in [build_i01,build_i02]:
        m,f=make();missions[m['mission_id']]=m;fixtures[m['mission_id']]=f
        for g in m['goals']:
            if g['kind']!='sources_preserved':g.update({'label_display':m['goal_text'],'target_display':m['initial_web_url']})
    definition={'schema_version':1,'content_version':1,'campaign_id':'midnight_investigation','mode':'commissions','title':text('PACK_TITLE','선택 의뢰','Optional Commissions'),'summary':text('PACK_SUMMARY','관심 있는 분야만 골라 조사하는 클라우드 권한·배포 출처 의뢰입니다. 본편 진행과 엔딩에 필요하지 않습니다.','Choose cloud-authority or release-provenance investigations independently. Neither is required for the main story or its endings.'),'start_mission':'I01','mission_order':list(missions),'missions':missions,'endings':[]}
    keys=used_keys(definition)
    base.write(ROOT/'godot/data/campaign/packs/investigation_v1.json',definition)
    for loc in ['ko','en']:base.write(ROOT/f'godot/data/campaign/locales/investigation_v1.{loc}.json',{k:base.TEXT[PACK][loc][k] for k in sorted(keys)})
    base.write(ROOT/'godot/tests/fixtures/investigation_solutions.json',{'packs':{'investigation':{'missions':fixtures,'endings':[]}}})
    assert hashes()==before,'Original released content changed'
    assert len(missions)==2 and all(m['optional'] and not m['prerequisites'] for m in missions.values())
    print(json.dumps({'pack':'investigation','optional_cases':2,'routes':4,'locale_keys':len(keys),'preserved_inputs':len(before)}))


if __name__=='__main__':build()
