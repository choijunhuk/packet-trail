#!/usr/bin/env python3
"""Apply reviewed campaign revision translations, preserving observed technical records."""
import ast
import hashlib
import json
from check_locales import ROOT

DIRECTORY = ROOT / 'godot/locales'
# Update these only after reviewing changed prose in all four target languages.
REVIEWED_SOURCE = {'ko': '99ba19e3aadd6f17cd983004815f6e1f67bc3d0299ad6f779b778432006faec7', 'en': '5b9fb00531baa378f16477cf619b2658fae4ddf0ed9d2f6d2f2ba4dbec785ffd'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def build():
    sources = {}
    for locale in ('ko', 'en'):
        path = ROOT / f'godot/data/campaign/locales/{locale}.json'
        if hashlib.sha256(path.read_bytes()).hexdigest() != REVIEWED_SOURCE[locale]:
            raise ValueError(f'{locale}: source revision needs translation review')
        sources[locale] = read(path)
    ko, en = sources['ko'], sources['en']
    narrative = read(DIRECTORY / 'narrative.source.json')
    output = {key: value for key, value in read(DIRECTORY / 'campaign.source.json').items() if key in en}
    authored = read(DIRECTORY / 'guidance-drafts.json')
    proofs = read(DIRECTORY / 'proofs-drafts.json')
    prose = read(DIRECTORY / 'operational-prose.json')
    module = ast.parse((ROOT / 'tools/build_campaign_content.py').read_text(encoding='utf-8'))
    constants = {n.targets[0].id: ast.literal_eval(n.value) for n in module.body
                 if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) and n.targets[0].id in ('ACCESS', 'PROOFS')}
    for key, values in read(DIRECTORY / 'campaign-static.json').items():
        output[key] = [ko[key], en[key], *values]

    def assign(key, values):
        output[key] = [ko[key], en[key], *values]

    auth_intro = ['この事件の範囲で使える読み取り・点検アカウントです。読む権限があっても結論が確定するわけではありません。','这些是委托范围内的读取与检查账号。有权阅读不代表已证明结论。','Son cuentas de lectura e inspección autorizadas para el caso. Poder leer no determina la conclusión.','Dies sind zugelassene Lese- und Prüfkonten für den Fall. Leserechte belegen noch keine Schlussfolgerung.']
    for mid, entries in proofs.items():
        specs = constants['PROOFS'][mid]
        if len(specs) != len(entries):
            raise ValueError(f'{mid}: proof translation count differs')
        for number, (spec, (titles, findings)) in enumerate(zip(specs, entries), 1):
            prefix = f'{mid}_E{number}'
            assign(prefix + '_TITLE', titles)
            raw_a = en[prefix + '_FIELD'].split('\n\n', 1)[1]
            raw_b = en[prefix + '_RETAINED'].split('\n\n', 1)[1]
            reference = spec[6]
            assign(prefix + '_FIELD', [f'[{titles[0]} · 現場台帳]\n引き継がれた業務番号の観察を見つけ、二つの行を比べてください。似た無関係な行を混ぜると、別事件を同じものと誤認します。\n\n{raw_a}',f'[{titles[1]} · 现场台账]\n找到交接业务编号对应的观察，对比两条记录。混入相似的无关行会把不同事件混为一谈。\n\n{raw_a}',f'[{titles[2]} · Registro de campo]\nLocaliza las observaciones de la referencia recibida y compara ambas entradas. Mezclar una fila ajena de aspecto parecido confundiría incidentes distintos.\n\n{raw_a}',f'[{titles[3]} · Vor-Ort-Buch]\nFinde die Beobachtungen zur übergebenen Vorgangsreferenz und vergleiche beide Einträge. Ähnliche fremde Zeilen würden verschiedene Vorfälle vermischen.\n\n{raw_a}'])
            assign(prefix + '_RETAINED', [f'[{titles[0]} · 独立保管台帳]\n現場応答のコピーではなく、別の担当が保管した観察です。reference を前の業務番号と照合し、該当行だけを選んでください。\n\n{raw_b}',f'[{titles[1]} · 独立保管台账]\n这些观察由另一个部门独立保留，并非现场响应的复制。将 reference 与此前业务编号对应，仅选取相关行。\n\n{raw_b}',f'[{titles[2]} · Registro independiente]\nSon observaciones conservadas por otra oficina, no copiadas de la respuesta en directo. Relaciona reference con el identificador anterior y elige solo la fila pertinente.\n\n{raw_b}',f'[{titles[3]} · Unabhängiges Buch]\nEine andere Stelle bewahrte diese Beobachtungen auf, statt die Liveantwort zu kopieren. Ordne reference der vorherigen Vorgangskennung zu und wähle nur die passende Zeile.\n\n{raw_b}'])
            assign(prefix + '_FINDING', [f'[{titles[0]}]\n{findings[0]}\n\n業務参照: {reference}\n取得元と次の関連台帳を一緒に保存します。',f'[{titles[1]}]\n{findings[1]}\n\n业务引用：{reference}\n请一并保留取得来源与下一个相关台账。',f'[{titles[2]}]\n{findings[2]}\n\nReferencia del caso: {reference}\nConserva juntos el origen de adquisición y el siguiente registro relacionado.',f'[{titles[3]}]\n{findings[3]}\n\nVorgangsreferenz: {reference}\nBewahre Erwerbsquelle und nächstes zugehöriges Buch gemeinsam auf.'])
        goals, clues = authored[mid]
        titles_by_locale = [[entry[0][index] for entry in entries] for index in range(4)]
        source_brief = en[mid + '_BRIEF']
        account_lines = source_brief.split('[Case access]\n', 1)[1].split('\nIndependent exhibits required:', 1)[0].strip()
        field_access = source_brief.split('[Field ledger access]\n', 1)[1].splitlines()[0]
        retained_access = source_brief.split('[Independent ledger access]\n', 1)[1].splitlines()[0]
        brief = narrative[mid + '_BRIEF']
        for index in range(4):
            base = brief[index + 2].split('\n\n' + auth_intro[index], 1)[0]
            heads = [('事件のアクセス','必要な独立証拠','現場台帳へのアクセス','独立台帳へのアクセス','依頼に記された業務番号に対応する台帳ファイル名を読んでください。'),('事件访问','所需独立证据','现场台账访问','独立台账访问','请阅读委托中业务编号所对应的台账文件名。'),('Acceso al caso','Pruebas independientes necesarias','Acceso al registro de campo','Acceso al registro independiente','Lee los nombres de archivo de las referencias indicadas en el encargo.'),('Fallzugang','Benötigte unabhängige Belege','Zugang zum Vor-Ort-Buch','Zugang zum unabhängigen Buch','Lies die Dateinamen zu den Vorgangsreferenzen des Auftrags.')][index]
            brief[index + 2] = f'{base}\n\n{auth_intro[index]}\n\n[{heads[0]}]\n{account_lines}\n\n{heads[1]}: {", ".join(titles_by_locale[index])}\n[{heads[2]}]\n{field_access}\n[{heads[3]}]\n{retained_access}\n{heads[4]}\n'
        assign(mid + '_GOAL', [goal + '\n' + prefix + ' → '.join(titles) for goal, prefix, titles in zip(goals,['追加の立証: ','补充证明：','Hallazgos adicionales: ','Zusätzliche Feststellungen: '],titles_by_locale)])
        assign(mid + '_HINT_1', [prefix + clue for prefix, clue in zip(['まず不足している証拠と業務番号を確かめてください。','先确认缺少的证据及业务编号。','Identifica primero la prueba que falta y su referencia. ','Bestimme zuerst den fehlenden Beleg und seine Vorgangsreferenz. '],clues)])
        host_a, host_b = constants['ACCESS'][mid][4:]
        assign(mid + '_HINT_2', [f'{host_a}.packet.test の現場台帳か、{host_b}.packet.test の独立台帳で同じ業務番号を探してください。前の証拠が確定すると次の段階が開きます。',f'在 {host_a}.packet.test 的现场台账或 {host_b}.packet.test 的独立台账中寻找同一业务编号。前一步证据确认后才能进入下一阶段。',f'Busca la misma referencia en {host_a}.packet.test o en el registro independiente de {host_b}.packet.test. La etapa siguiente se abre al establecer la prueba anterior.',f'Suche dieselbe Vorgangsreferenz auf {host_a}.packet.test oder im unabhängigen Buch auf {host_b}.packet.test. Erst der vorherige Beleg öffnet den nächsten Schritt.'])
        assign(mid + '_HINT_3', ['現場の二つの観察を比べるか、独立台帳で reference= に業務番号を続けて該当行を絞ってください。中心資料の後には、解釈と範囲の証拠も必要です。','比较现场的两项观察，或在独立台账中以 reference= 后接业务编号筛选相关行。核心证据之后，还须确认解释与范围。','Compara las dos observaciones de campo o filtra el registro independiente con reference= seguido de la referencia del caso. Tras la prueba principal, establece también interpretación y alcance.','Vergleiche beide Vor-Ort-Beobachtungen oder filtere das unabhängige Buch mit reference= gefolgt von der Vorgangsreferenz. Belege nach dem Hauptnachweis auch Deutung und Umfang.'])
        raw_context = en[mid + '_CONTEXT'].split('\n\n', 2)[2]
        raw_route = en[mid + '_ROUTE'].split('\n\n', 1)[1]
        contexts, routes = [], []
        for index in range(4):
            context, route = raw_context, raw_route
            for original, translated in prose.items():
                context, route = context.replace(original, translated[index]), route.replace(original, translated[index])
            intro = ['業務台帳から該当する行を探してください。名前や時刻が似た別事件と混同しないでください。以下の識別値、要求、パスは観察原文のままです。','请在业务台账中定位相关条目，不要混淆名称或时刻相似的其他事件。以下标识、请求与路径按原始观察保留。','Localiza las entradas pertinentes. No confundas otro suceso de nombre u hora parecidos. Identificadores, peticiones y rutas conservan su forma observada.','Finde die passenden Einträge im Arbeitsbuch. Verwechsle keine fremden Ereignisse ähnlichen Namens oder Zeitpunkts. Kennungen, Anfragen und Pfade bleiben wie beobachtet.'][index]
            contexts.append(f'[{goals[index]}]\n\n{intro}\n\n{context}')
            route_intro = ['[独立保管担当者の作業メモ]\nこの観察台帳は現場応答と独立して残されました。該当する業務番号を探し、現在の事件台帳と比べてください。','[独立保管人的工作便条]\n此观察台账独立于现场响应保留。请找到相关业务编号，与当前事件台账对比。','[Nota del custodio independiente]\nEste registro se conservó de forma independiente a la respuesta en directo. Busca la referencia pertinente y compárala con el caso actual.','[Arbeitsnotiz der unabhängigen Verwahrung]\nDieses Beobachtungsbuch entstand unabhängig von der Liveantwort. Finde die passende Vorgangsreferenz und vergleiche sie mit dem aktuellen Fall.'][index]
            routes.append(route_intro + '\n\n' + route)
        assign(mid + '_CONTEXT', contexts)
        assign(mid + '_ROUTE', routes)
        prefix = en[mid + '_HOST_NAME'].removesuffix(' Work Service')
        assign(mid + '_HOST_NAME', [prefix + ' 業務サービス',prefix + ' 业务服务','Servicio de trabajo ' + prefix,'Arbeitsdienst ' + prefix])
        assign(mid + '_AUDIT_NAME', [prefix + ' 独立保管先',prefix + ' 独立保管处','Custodia independiente ' + prefix,'Unabhängige Verwahrung ' + prefix])
        assign(mid + '_EVIDENCE_A_HOST', ['現場観察台帳','现场观察台账','Registro de observación de campo','Vor-Ort-Beobachtungsbuch'])
        assign(mid + '_EVIDENCE_B_HOST', ['独立保管台帳','独立保管台账','Registro de custodia independiente','Unabhängiges Verwahrbuch'])
        raw_record = 'NIGHT HANDOFF' + en[mid + '_AUDIT'].split('NIGHT HANDOFF', 1)[1]
        old_audit = output[mid + '_AUDIT'][2:]
        assign(mid + '_AUDIT', [value.split('\n\nNIGHT HANDOFF', 1)[0] + '\n\n' + raw_record for value in old_audit])
    for rows in (narrative, output):
        for key in rows:
            rows[key][:2] = [ko[key], en[key]]
    known = set(narrative) | set(output)
    if known != set(en):
        raise ValueError(f'untranslated keys={sorted(set(en)-known)}, stale keys={sorted(known-set(en))}')
    for name, rows in [('narrative.source.json', narrative), ('campaign.source.json', output)]:
        (DIRECTORY / name).write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'ok': True, 'campaign_keys': len(en), 'extra_languages': 4}))


if __name__ == '__main__':
    build()
