# Hız Ölçer

Hız Ölçer, telefon kamerasındaki insan, bisiklet, araç ve seçili top türlerini cihaz üzerinde algılayıp takip ederek tahmini hız sunmayı amaçlayan bir iOS ve Android projesidir.

Proje şu anda teknik fizibilite aşamasındadır. Kullanıcıdan mesafe veya kalibrasyon girişi alınmaz. Gerçek ölçeğin nesne türüne ve görüntü geometrisine göre otomatik tahmin edilmesi araştırılacaktır. Bu tahmin doğrulanmadan ölçüm kesin veya resmî hız ölçümü olarak sunulmaz.

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


## M0 geliştirme kabuğu

Mevcut uygulama yalnızca açıkça etiketlenmiş koyu/nane arayüz prototipidir.
Kamera, algılama, takip, otomatik ölçek ve hız ölçümü henüz uygulanmamıştır.
Kurulum, sabit sürümler, doğrulama komutları ve zorunlu Mac/Xcode kontrolleri:
[Development guide](docs/DEVELOPMENT.md).

## M1: model bekleyen çevrimdışı test düzeneği

Uygulamadaki etiketli offline ekran, yalnızca repoda yazılmış sentetik gözlem
senaryosunu çalıştırır. Gerçek model, video içe aktarma/decoder ve hız üretimi yoktur.
[Çalıştırma, kanıt şeması ve kalan M1 engelleri](docs/M1_OFFLINE_HARNESS.md).
