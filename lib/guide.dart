import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'study_round.dart';
import 'theme.dart';
import 'widgets.dart';

// วิธีเรียนให้ได้ผล — why listening, AI explanations and rereading slides
// leave little behind, and what to do instead: read first, clear the stuck
// points with AI, pull it out from memory, let AI quiz. Where knowledge comes
// from, what to read per subject, and handling the stress.

Future<void> openGuide(BuildContext context, Store store) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuidePage(store: store)));

const _flowNew = <(IconData, String, String, Color)>[
  (Icons.menu_book_rounded, 'อ่านเอง', 'ทีละหัวข้อ · งงตรงไหนจนค้างใจ ถาม AI ได้เลย', Color(0xFF82BAB0)),
  (Icons.draw_rounded, 'ปิดแล้วดึงออก', 'เขียน วาด เล่า ทำโจทย์ จากความจำ · ให้ AI ตรวจ', Color(0xFFE58BAB)),
  (Icons.replay_rounded, 'แก้แล้วลองใหม่', 'อ่านเฉพาะตรงที่ผิด แล้วปิดสไลด์ลองใหม่ · ทวนอีกในวันถัดไป', Color(0xFFB48BD9)),
];

const _sources = <(String, String, Color)>[
  ('สไลด์ + สิ่งที่ครูพูด', 'หลัก · ข้อสอบออกจากตรงนี้', Color(0xFFE58BAB)),
  ('การบ้าน · แล็บ · ข้อสอบเก่า', 'ฝึกใช้จริง · รู้แนวข้อสอบ', Color(0xFFE2B866)),
  ('คลิป · หนังสือ', 'เมื่อสไลด์ไม่เห็นภาพ', Color(0xFF82BAB0)),
  ('AI', 'เคลียร์จุดที่ติด · ทดสอบเรา', Color(0xFFB48BD9)),
];

/// Per subject: what to read or watch (tap copies the name to search), and
/// what to do with the hands.
const _resources = <(String, String, List<(String, String)>, String)>[
  ('CN320 · CN321', 'เครือข่าย', [
    ('Jeremy\'s IT Lab (YouTube)', 'คอร์ส CCNA ฟรี อธิบายเห็นภาพ มีแล็บให้ทำตาม'),
    ('Forouzan: Data Communications and Networking', 'ตำราสาย data comm อ่านเฉพาะบทที่ตรงสไลด์'),
    ('Kurose & Ross: Computer Networking', 'อธิบายแต่ละ layer จากบนลงล่าง'),
  ], 'Cisco Packet Tracer · โหมด Simulation ดูแพ็กเก็ตวิ่งทีละ hop'),
  ('CN310', 'Server', [
    ('linuxjourney.com', 'พื้นฐาน Linux ทีละขั้น'),
    ('DigitalOcean Tutorials', 'ค้น "how to set up DNS server" ฯลฯ มีขั้นตอนครบ'),
  ], 'Linux ใน VirtualBox · ตั้ง DHCP, DNS, web server เอง พังได้ ลบแล้วทำใหม่'),
  ('CN360', 'Microcontroller', [
    ('เอกสารของบอร์ดที่ใช้ในวิชา', 'Arduino docs หรือ STM32 reference ตามที่เรียน'),
  ], 'Wokwi หรือ Tinkercad · จำลองบอร์ดบนเว็บ เปลี่ยนโค้ดแล้วดูผล'),
  ('CN361', 'Microprocessor', [
    ('Ben Eater (YouTube)', 'สร้างคอมจากชิปทีละตัว เห็น bus, register, CPU ทำงานจริง'),
    ('หนังสือตาม syllabus', 'อ่านบทที่ตรงกับสไลด์'),
  ], 'ไล่ assembly ทีละบรรทัดบนกระดาษ เขียนค่า register ทุกบรรทัด'),
  ('CN330', 'App Development', [
    ('Docs ทางการของภาษาที่เรียน', 'ดูตัวอย่างโค้ดจริง'),
    ('refactoring.guru', 'OOP และ design pattern เป็นภาพ'),
  ], 'เขียนแอปเล็ก ๆ ของตัวเองให้จบ 1 ตัว ใช้ class, inheritance, interface'),
  ('CN331', 'Software Engineering', [
    ('Sommerville: Software Engineering', 'ตำรามาตรฐานของวิชานี้'),
  ], 'วาด UML ของแอปที่ใช้ทุกวัน เช่น แอปสั่งอาหาร'),
];

const _swaps = <(String, String, String)>[
  ('ฟังในห้องเฉย ๆ', 'เสียงเข้าหู แต่สมองไม่ได้ทำงานกับมัน ฟังแล้วรู้สึกเข้าใจ พอครูหยุดพูดก็หายไป',
      'ตั้งคำถามก่อนคาบ 1 ข้อ · จดด้วยคำของตัวเอง · หลังคาบเขียน 3 ประเด็นจากความจำ (ใช้ "เรียนในห้อง")'),
  ('ให้ AI สอนสไลด์', 'คำอธิบายดี ๆ ทำให้รู้สึกเข้าใจ แต่คนที่คิดคือ AI ไม่ใช่เรา',
      'ให้ AI เป็นคนถาม เราเป็นคนตอบ แล้วให้มันตรวจว่าผิดตรงไหน (มีคำสั่งให้คัดลอกด้านล่าง)'),
  ('ไม่ค่อยทำการบ้าน', 'การบ้านคือที่เดียวที่ได้ลองใช้ความรู้จริง ข้ามไป = ข้ามส่วนที่สำคัญที่สุด',
      'การบ้านคือการเตรียมสอบ ทำภายใน 2 วันหลังคาบ ไม่อยากเริ่ม กด "เริ่มแค่ 2 นาที"'),
  ('อ่านสไลด์จบแล้วเข้าสอบ', 'อ่านซ้ำทำให้ "คุ้นตา" ไม่ใช่ "จำได้" ในห้องสอบไม่มีสไลด์ให้คุ้น',
      'ปิดสไลด์ แล้วเขียนหรืออธิบายออกมา · ทำโจทย์ · ทำข้อสอบเก่า'),
];

const _principles = <(IconData, String, String)>[
  (Icons.upload_rounded, 'ดึงออก มากกว่าใส่เข้า',
      'ปิดหนังสือแล้วถามตัวเองว่า "เมื่อกี้เรื่องอะไร" เขียนออกมาให้ได้มากที่สุด ตรงที่นึกไม่ออก คือตรงที่ต้องกลับไปอ่าน การนึกให้ออกแม้จะยาก คือตัวที่ทำให้จำได้นาน'),
  (Icons.construction_rounded, 'ลงมือทำ มากกว่าอ่าน',
      'วิชาคอมเรียนด้วยการทำ ตั้งค่าเครือข่ายเอง เขียนโค้ดเอง ไล่ assembly เอง ทำผิดแล้วแก้ ได้มากกว่าอ่านถูก 10 รอบ'),
  (Icons.event_repeat_rounded, 'ทวนเว้นระยะ',
      'อ่านวันนี้ ทวนพรุ่งนี้ อีก 3 วัน อีก 1 สัปดาห์ ทวนครั้งละ 10 นาทีด้วยการถามตัวเอง จะจำได้ถึงปีหน้า ไม่ใช่ลืมหลังสอบ (การ์ดทวนจำ + หน้าเตรียมสอบช่วยเตือน)'),
  (Icons.draw_rounded, 'ทำให้เห็นภาพ',
      'วาดรูปทุกครั้งที่ทำได้: แพ็กเก็ตเดินทางผ่านอะไรบ้าง ข้อมูลไหลผ่าน bus ยังไง class ไหนเรียก class ไหน ถ้าวาดไม่ได้ แปลว่ายังไม่เห็นภาพ ให้หาตัวอย่างจริงหรือลองในเครื่อง'),
  (Icons.record_voice_over_rounded, 'อธิบายให้คนอื่นฟัง',
      'อธิบายเรื่องหนึ่งให้เพื่อน ให้น้อง หรือพูดคนเดียวเหมือนสอน ติดตรงไหน = ยังไม่เข้าใจตรงนั้น ถ้าอธิบายได้ด้วยภาษาง่าย ๆ แปลว่าเข้าใจจริง'),
];

const _cycle = <(String, String)>[
  ('ก่อนคาบ', 'เปิดสไลด์ดูหัวข้อคร่าว ๆ ไม่ต้องเข้าใจ ตั้งคำถาม 1 ข้อที่อยากรู้ สมองจะคอยหาคำตอบตลอดคาบ'),
  ('ในคาบ', 'ฟังหา "ทำไม" ไม่ใช่แค่ "อะไร" · จดด้วยคำตัวเอง · วาดรูป · ไม่เข้าใจตรงไหนเขียนเครื่องหมาย ? ไว้ แล้วถามครูหรือเพื่อน'),
  ('หลังคาบ วันเดียวกัน', 'ก่อนเปิดสมุด เขียน 3 เรื่องสำคัญจากความจำ แล้วค่อยเปิดเทียบ เติมที่ขาด ทำเป็นการ์ดทวนจำ'),
  ('ภายใน 2 วัน', 'ทำการบ้าน หรือโจทย์ 3–5 ข้อ ติดแล้วค่อยเปิดสไลด์ดูเฉพาะตรงนั้น'),
  ('สุดสัปดาห์', 'ทวนการ์ด · วาดแผนภาพรวมของสัปดาห์จากความจำ · เคลียร์เครื่องหมาย ? ที่ค้าง'),
];

/// One habit at a time: each week adds one, keeping the ones before.
const _ladder = <(String, String)>[
  ('ดึงออกทุกครั้ง', 'อ่านหรือดูอะไรจบ ปิดแล้วเล่าออกมาเองทุกครั้ง แค่นิสัยนี้อย่างเดียว ก็ต่างจากเดิมมาก'),
  ('การบ้านไม่หลุด', 'ทำการบ้านและแล็บทุกชิ้น ติดก็ถาม ไม่ต้องสวย แค่ได้ลองใช้ความรู้จริง'),
  ('คาบเรียนคุ้ม', 'ทุกคาบเขียน 3 ประเด็นจากความจำหลังเลิก และเคลียร์ ? ภายในสัปดาห์'),
  ('ซ้อมเหมือนจริง', 'ทำข้อสอบเก่าจับเวลา ดูว่าผิดเพราะไม่รู้ หรือเพราะรีบ แล้วแก้ตรงนั้น'),
];

/// Ask these at the end of each week and change one thing.
const _check = [
  'สัปดาห์นี้ ปิดหนังสือแล้วอธิบายได้กี่เรื่อง',
  'เรื่องไหนอ่านแล้ว แต่พอปิดแล้วยังว่างเปล่า',
  'อะไรทำให้ไม่ได้เริ่ม หรือหลุดบ่อยที่สุด',
  'สัปดาห์หน้า จะเปลี่ยนอะไร 1 อย่าง',
];

const _prompts = <(String, String)>[
  ('ให้ AI ถาม เราตอบ',
      'จากสไลด์นี้ อย่าเพิ่งอธิบาย ถามฉันทีละข้อ 5 ข้อ เริ่มจากง่ายไปยาก รอให้ฉันตอบก่อนทุกข้อ แล้วบอกว่าถูกหรือผิด ผิดตรงไหน และเพราะอะไร'),
  ('ให้เราอธิบาย AI จับผิด',
      'ฉันจะอธิบายเรื่อง [หัวข้อ] ให้ฟังด้วยคำของฉัน ช่วยชี้ว่าตรงไหนเข้าใจผิด ตรงไหนขาด และถามคำถามต่อ 1 ข้อเพื่อเช็กว่าฉันเข้าใจจริง'),
  ('ขอภาพ ขอตัวอย่างจริง',
      'อธิบาย [หัวข้อ] ด้วยการเปรียบเทียบกับของในชีวิตประจำวัน 1 อย่าง และตัวอย่างการใช้งานจริงในงานคอมพิวเตอร์ 1 อย่าง แล้วถามฉันให้ลองเปรียบเทียบเองอีก 1 อย่าง'),
  ('ออกข้อสอบจำลอง',
      'ออกโจทย์แบบข้อสอบปลายภาควิชา [ชื่อวิชา] เรื่อง [หัวข้อ] 3 ข้อ ระดับปานกลางถึงยาก ห้ามเฉลยจนกว่าฉันจะส่งคำตอบ แล้วตรวจให้คะแนนพร้อมเหตุผล'),
  ('หาจุดที่ตกหล่น',
      'นี่คือสิ่งที่ฉันสรุปจากความจำ: [วางสรุป] เทียบกับสไลด์แล้วบอกว่าฉันตกหล่นประเด็นสำคัญอะไรบ้าง ยังไม่ต้องอธิบาย แค่บอกหัวข้อ ฉันจะไปอ่านเอง'),
];

class GuidePage extends StatelessWidget {
  final Store store;
  const GuidePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget h(String t, [String? sub]) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: display(context, 20)),
            if (sub != null) Text(sub, style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5)),
          ]),
        );
    final body = TextStyle(color: p.ink, height: 1.6, fontSize: 14);
    final muted = TextStyle(color: p.muted, height: 1.6, fontSize: 13);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.bg, title: Text('วิธีเรียนให้ได้ผล', style: display(context, 19))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        Panel(
          border: p.lotus,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ไม่ใช่ว่าเราไม่เก่ง', style: display(context, 20).copyWith(color: p.lotus)),
            const SizedBox(height: 6),
            Text('ฟัง อ่าน ให้ AI อธิบาย ทั้งหมดคือ "ใส่เข้า" ความรู้จะติดหัวก็ต่อเมื่อเรา "ดึงออก" มาใช้เอง '
                'ถ้าเปลี่ยนวิธี แม้เวลาเท่าเดิม ผลจะต่างไปมาก', style: body),
          ]),
        ),

        h('ลำดับการเรียน', 'AI ใช้ได้ทุกขั้นที่ช่วยให้เข้าใจ · แต่อย่าหยุดแค่ตอน AI อธิบายจบ'),
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('แบบเดิม', style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text('AI อ่านแล้วสอน → อ่านสไลด์ → เข้าสอบ',
                style: body.copyWith(color: p.muted, decoration: TextDecoration.lineThrough)),
            Text('ทุกขั้นคือใส่เข้า ไม่มีขั้นไหนที่เราต้องดึงออกเอง', style: muted.copyWith(fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 12),
        Text('แบบใหม่', style: TextStyle(color: p.lotus, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final (i, (icon, t, d, c)) in _flowNew.indexed) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: c.withValues(alpha: .13),
              border: Border.all(color: c.withValues(alpha: .55)),
            ),
            child: Row(children: [
              Text('${i + 1}', style: number(context, 22).copyWith(color: c)),
              const SizedBox(width: 12),
              Icon(icon, color: c),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: display(context, 16)),
                  Text(d, style: muted.copyWith(fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
          if (i < _flowNew.length - 1) Center(child: Icon(Icons.arrow_downward_rounded, color: p.muted, size: 20)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => openStudyRound(context, store),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('ลองรอบอ่าน 3 ขั้น'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 4),
        Text('แอปพาทำทีละขั้น ไม่จับเวลา แต่ละขั้นบอกว่าทำถึงไหนถึงพอ พร้อมคำสั่ง AI ให้คัดลอก · ในหน้าเตรียมสอบ ปุ่ม ▶ ของทุกหัวข้อก็เปิดรอบนี้',
            style: muted.copyWith(fontSize: 12.5)),

        h('ความรู้เอามาจากไหน', 'เรียงจากสำคัญที่สุด · ใช้ตัวบนเป็นหลัก ตัวล่างเป็นตัวช่วย'),
        for (final (i, (t, d, c)) in _sources.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 1 - i * .12,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                decoration: BoxDecoration(color: c.withValues(alpha: .2), borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: c, width: 4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. $t', style: display(context, 15)),
                  Text(d, style: muted.copyWith(fontSize: 12)),
                ]),
              ),
            ),
          ),

        h('อ่านอะไรเพิ่ม แยกตามวิชา', 'ใช้เฉพาะตอนสไลด์ไม่พอ ไม่ต้องอ่านทั้งเล่ม · แตะชื่อเพื่อคัดลอกไปค้น'),
        for (final (code, name, reads, doIt) in _resources)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: code, style: display(context, 16).copyWith(color: p.pond)),
                  TextSpan(text: '  $name', style: muted),
                ])),
                const SizedBox(height: 6),
                for (final (r, why) in reads)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: r.replaceAll(' (YouTube)', '')));
                      HapticFeedback.selectionClick();
                      toast(context, 'คัดลอก "$r" แล้ว');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.menu_book_outlined, size: 17, color: p.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r, style: body.copyWith(fontWeight: FontWeight.w500, fontSize: 13.5)),
                            Text(why, style: muted.copyWith(fontSize: 12)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.construction_rounded, size: 17, color: p.lotus),
                  const SizedBox(width: 8),
                  Expanded(child: Text(doIt, style: body.copyWith(fontSize: 13.5))),
                ]),
              ]),
            ),
          ),
        Text('ถามอาจารย์หรือดู syllabus ว่าใช้หนังสือเล่มไหน แล้วใช้เล่มนั้นเป็นหลัก', style: muted.copyWith(fontSize: 12.5)),

        h('สิ่งที่ทำอยู่ → ทำแบบนี้แทน'),
        for (final (old, why, now) in _swaps)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(old, style: display(context, 16).copyWith(decoration: TextDecoration.lineThrough, color: p.muted)),
                Text(why, style: muted),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.arrow_forward_rounded, size: 18, color: p.pond),
                  const SizedBox(width: 6),
                  Expanded(child: Text(now, style: body.copyWith(fontWeight: FontWeight.w500))),
                ]),
              ]),
            ),
          ),

        h('หลัก 5 ข้อ', 'ทุกวิธีด้านล่างมาจากหลักเหล่านี้'),
        for (final (icon, t, d) in _principles)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: p.pond.withValues(alpha: .15), shape: BoxShape.circle),
                child: Icon(icon, color: p.pond, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: display(context, 16)),
                  Text(d, style: muted),
                ]),
              ),
            ]),
          ),

        h('หนึ่งคาบ เรียนครบวงจร', 'เพิ่มงานต่อคาบไม่มาก แต่ไม่ต้องมานั่งอ่านใหม่หมดตอนสอบ'),
        for (final (i, (t, d)) in _cycle.indexed)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.lotus, shape: BoxShape.circle),
                child: Text('${i + 1}', style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (i < _cycle.length - 1) Container(width: 2, height: 54, color: p.line),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: display(context, 15.5)),
                  Text(d, style: muted),
                ]),
              ),
            ),
          ]),

        h('ใช้ AI ให้เป็นครูที่ถาม ไม่ใช่ครูที่พูด', 'แตะเพื่อคัดลอก แล้ววางพร้อมสไลด์ แก้ [ ] ให้ตรงเรื่อง'),
        for (final (t, prompt) in _prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Clipboard.setData(ClipboardData(text: prompt));
                HapticFeedback.selectionClick();
                toast(context, 'คัดลอกแล้ว');
              },
              child: Panel(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: display(context, 15).copyWith(color: p.lotus)),
                      const SizedBox(height: 2),
                      Text(prompt, style: muted),
                    ]),
                  ),
                  Icon(Icons.copy_rounded, size: 18, color: p.muted),
                ]),
              ),
            ),
          ),
        Text('กฎเดียว: ถ้า AI พูดมากกว่าเรา แปลว่าเรากำลังใส่เข้าอีกแล้ว', style: muted.copyWith(fontStyle: FontStyle.italic)),

        h('พาตัวเองเก่งขึ้น ทีละสัปดาห์', 'ไม่ต้องเปลี่ยนทุกอย่างพร้อมกัน เพิ่มทีละนิสัย และเก็บนิสัยเดิมไว้'),
        for (final (i, (t, d)) in _ladder.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: 8, left: i * 14.0),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              border: p.pond.withValues(alpha: .25 + i * .2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('สัปดาห์ที่ ${i + 1} · $t', style: display(context, 15).copyWith(color: p.pond)),
                Text(d, style: muted.copyWith(fontSize: 12.5)),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('เช็กตัวเองทุกวันอาทิตย์', style: display(context, 16)),
            const SizedBox(height: 4),
            for (final q in _check)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_box_outline_blank_rounded, size: 18, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(q, style: body.copyWith(fontSize: 13.5))),
                ]),
              ),
            const SizedBox(height: 6),
            Text('วัดความเก่งจาก "อธิบายได้ ทำโจทย์ได้" ไม่ใช่จากชั่วโมงที่อ่าน', style: muted.copyWith(fontSize: 12.5)),
          ]),
        ),

        h('ก่อนสอบ'),
        for (final t in [
          'ทำข้อสอบเก่าแบบจับเวลาจริง แล้วดูว่าผิดเพราะไม่รู้ หรือเพราะรีบ',
          'เขียนสรุปทั้งวิชาลงกระดาษ 1 หน้า จากความจำ แล้วค่อยเปิดเทียบ',
          'คืนก่อนสอบ ทวนการ์ดกับสรุป 1 หน้า ไม่อ่านเรื่องใหม่ และนอนให้พอ',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: p.lotus)),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: body)),
            ]),
          ),

        h('ตอนรู้สึกว่า "ไม่มีอะไรในหัว"'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ความรู้สึกนี้ไม่ใช่ความจริงทั้งหมด เรียนผ่านมาแล้ว 88 หน่วยกิต '
                'และเคยเปลี่ยน F เป็น B+ ได้ในเทอมเดียว ตอนที่ตั้งใจแบบมีวิธี', style: body),
            const SizedBox(height: 8),
            Text('พื้นฐานไม่ได้มาจากการอ่านเยอะ แต่มาจากโจทย์ทีละข้อที่ทำได้เอง ทุกข้อที่ทำได้ คือของที่อยู่ในหัวจริง '
                'และสะสมไปถึงวันฝึกงาน', style: body),
            const SizedBox(height: 8),
            Text('เครียดจนคิดไม่ออก ใช้ "ใจขุ่น · กังวล" ในหน้าวันนี้ 3 นาที หรือคุยกับเพื่อน ครอบครัว '
                'หรือศูนย์ให้คำปรึกษาของมหาวิทยาลัย ไม่ต้องแบกคนเดียว', style: muted),
          ]),
        ),

        h('ทุกวันจนถึงวันสอบ'),
        for (final (i, t) in [
          'เปิดหน้าเตรียมสอบ ทำรอบ 3 ขั้นตามที่แอปเลือก อย่างน้อยวันละ 2 รอบ',
          'ทุกคาบใช้ "เรียนในห้อง" · การบ้านทำภายใน 2 วัน',
          '2 สัปดาห์สุดท้าย ทำข้อสอบเก่าจับเวลาจริง',
          'นอน 7 ชั่วโมงขึ้นไป',
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('${i + 1}. $t', style: body),
          ),
      ]),
    );
  }
}
