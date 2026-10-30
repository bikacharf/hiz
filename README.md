# Hız Ölçer

Hız Ölçer, telefon kamerasındaki insan, bisiklet, araç ve seçili top türlerini cihaz üzerinde algılayıp takip ederek tahmini hız üreten iOS ve Android uygulamasıdır.

Proje şu anda teknik fizibilite aşamasındadır. Kullanıcıdan mesafe veya kalibrasyon girişi alınmaz. Gerçek ölçek, nesne türüne ve görüntü geometrisine göre otomatik tahmin edilir. Bu tahmin doğrulanmadan ölçüm kesin veya resmî hız ölçümü olarak sunulmaz.

## Başlangıç belgeleri

- [Ürün kapsamı](docs/SPEC.md)
- [Teknik mimari](docs/ARCHITECTURE.md)
- [Aşamalar ve kabul ölçütleri](docs/MILESTONES.md)
- [Cloud çalışma kuralları](docs/RUNBOOK.md)
- [Güncel durum](docs/STATUS.md)
- [İlk Cloud görevi](docs/CLOUD_TASK_01.md)

## Temel ilkeler

- Kamera görüntüsü varsayılan olarak cihaz üzerinde işlenir.
- Ölçüm kalitesi yetersizse hız gösterilmez.
- İnsan, bisiklet, araç ve top için ayrı doğrulama yapılır.
- iOS çalışması Mac ve gerçek iPhone üzerinde doğrulanmadan tamamlanmış sayılmaz.
- Ticari uygulamayla uyumsuz lisanslı kod veya model eklenmez.

