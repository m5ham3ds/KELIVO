# تعليمات تسليم العمل — KELIVO / Phase 14E

الحالة المرجعية: 27 نوفمبر 2026. المستودع `m5ham3ds/KELIVO`، والفرع النشط `main`، وآخر CI ناجح #208 على commit `77736b783d55752a35a3aeb3b66b6b6dce7e87f1`.

**المرحلة الحالية:** Phase 14E.1 و14E.2 اجتازتا الاختبارات المخصصة؛ Phase 14E ككل لم تُقبل بعد. يجب متابعة استكمال Toolsets الحقيقية وتكافؤ الأدوات الأصلية والتعريض direct/deferred/hidden وحدود budgets واختبارات الموافقات والإلغاء وثبات MCP route snapshot. لا تبدأ 14F قبل بوابة 14E كاملة.

قبل أي تعديل:
1. اقرأ `phases/README.md` و`phases/MASTER-DEVELOPMENT-PLAN-AR.md` و`PHASE-14-UNIVERSAL-SKILLS-PLUGINS-TOOLS-AND-AGENT-ORCHESTRATION-AR.md` و`PHASE-14E-IMPLEMENTATION-STATUS-AR.md`.
2. افحص `main` وعمليات Actions الأحدث؛ لا تعتمد على CI #208 إذا ظهرت عملية أحدث.
3. اتبع `GIT-BRANCHING-POLICY-AR.md`، ولا تنشئ فرعاً جديداً؛ لا تعمل على الفرع التاريخي `phase-14c5-mrtr-subscriptions`.
4. لا تعِد Phase 14A–14D أو الاختبارات التي اجتازت بواباتها ما لم يمسها تغيير مشترك.
5. لا تستبدل ToolCallHandler أو Approval Gateway أو MCP routing بمسار موازٍ. لا تدّعِ أن PRoot Kernel Sandbox، ولا أن اختبارات Emulator هي اختبار Force Stop على هاتف حقيقي.

أدلة CI #208: [Actions](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283) · [APK](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167472926) · [Build report](https://github.com/m5ham3ds/KELIVO/actions/runs/45926843283/artifacts/15167378117).
