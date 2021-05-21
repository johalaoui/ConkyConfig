# ConkyConfig
## Intro
This is an important part of my conky configuration. It is not complete, but you can customize it to your liking.
## Additional Infos
The amount of threads are detected automatically. There are variables to change the width of conky in `conky.conf`. `inceptionGetCpu` needs a resolution specific width (`widthBarThread`), which I made by using GIMP and counting the pixels. `widthBarThread` is the width of the `cpubar`s. The load color can be changed to red or otherwise.\
The GPU part uses `nvidia-smi` to get the information about one GPU.\
The network part will show networks with the name of `enp.*` (LAN) and `wlp.*` (WLAN) when available. This needs to be changed if the cards are named something else.
## Preview
![conky](conky.png)
