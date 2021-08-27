# BoidsMeshAnimation
[Boids]{https://ja.wikipedia.org/wiki/%E3%83%9C%E3%82%A4%E3%83%89_(%E4%BA%BA%E5%B7%A5%E7%94%9F%E5%91%BD)#:~:text=%E3%83%9C%E3%82%A4%E3%83%89(Boids)%E3%81%AF%E3%80%81%E3%82%A2%E3%83%A1%E3%83%AA%E3%82%AB,%E3%81%8B%E3%82%89%E5%8F%96%E3%82%89%E3%82%8C%E3%81%A6%E3%81%84%E3%82%8B%E3%80%82} の原理を用いてメッシュのアニメーションを粒子で模倣するプログラムです。
一部の粒子はメッシュ頂点に追従するようPD制御を行っており, 残りについてはメッシュ内部では Boids に基づく自由状態, 外部では内部に戻るようPD 制御を行っている。

外部オブジェクトを避けるインタラクションも行うことができる.


[![](https://img.youtube.com/vi/wcvwxlFzYEA/0.jpg)](https://www.youtube.com/watch?v=wcvwxlFzYEA)
