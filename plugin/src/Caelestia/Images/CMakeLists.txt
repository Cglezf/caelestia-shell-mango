qml_module(caelestia-images
    URI Caelestia.Images
    SOURCES
        cachingimageprovider.cpp
        imagecacher.cpp
        imageanalyser.cpp
        iutils.cpp
        windowcapture.cpp
        nativecapture.cpp
    LIBRARIES
        caelestia-protocols
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
)
