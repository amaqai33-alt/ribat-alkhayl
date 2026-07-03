# نتائج القسم ٢ — SuperAnimal

هنا تُحفظ:
- فيدioهات مُعلَّمة بنقاط المفاصل
- ملفات pose (csv/h5)
- `section-02-report.json`

## تشغيل

```bash
cd ~/Desktop/مدiول\ بصمة\ المشية
source .venv/bin/activate
python scripts/run-section-02.py        # الثلاثة
python scripts/run-section-02.py 03    # فيدio واحد
./scripts/check-section-02.sh
```

## ملاحظة

المعالجة على المعالج (بدون GPU) قد تستغرق **٣٠–٩٠ دقيقة لكل فيدio**.
