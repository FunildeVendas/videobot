FROM --platform=linux/amd64 ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

ENV project=attendee
ENV cwd=/$project

WORKDIR $cwd

ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    gdb \
    git \
    gfortran \
    libopencv-dev \
    libdbus-1-3 \
    libgbm1 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libglib2.0-dev \
    libssl-dev \
    libx11-dev \
    libx11-xcb1 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-xfixes0 \
    libxcb-xtest0 \
    libgl1-mesa-dri \
    libxfixes3 \
    linux-libc-dev \
    pkgconf \
    python3-pip \
    tar \
    unzip \
    zip \
    vim \
    libpq-dev \
    xvfb \
    x11-xkb-utils \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    xfonts-cyrillic \
    x11-apps \
    libvulkan1 \
    fonts-liberation \
    xdg-utils \
    wget \
    libasound2 \
    libasound2-plugins \
    alsa \
    alsa-utils \
    alsa-oss \
    pulseaudio \
    pulseaudio-utils \
    ffmpeg \
    universal-ctags \
    xterm \
    xmlsec1 \
    xclip \
    libavdevice-dev \
    gstreamer1.0-alsa \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgirepository1.0-dev \
    --fix-missing \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Install Google Chrome
RUN wget -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome-stable_current_amd64.deb \
    && rm -f /tmp/google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Install a matching ChromeDriver version dynamically
RUN CHROME_VERSION=$(google-chrome --product-version | cut -d '.' -f 1-3) \
    && DRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${CHROME_VERSION}") \
    && wget -O /tmp/chromedriver-linux64.zip "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" \
    && unzip /tmp/chromedriver-linux64.zip -d /tmp \
    && mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
    && chmod +x /usr/local/bin/chromedriver \
    && rm -rf /tmp/chromedriver-linux64 /tmp/chromedriver-linux64.zip

# Install Python dependencies used before app requirements
RUN pip install --no-cache-dir pyjwt cython gdown python-dotenv

# Reinstall av against system libs
RUN pip uninstall -y av && pip install --no-binary av "av==12.0.0"

# Alias python3 to python
RUN ln -s /usr/bin/python3 /usr/bin/python

FROM base AS deps

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

WORKDIR /opt

FROM deps AS build

RUN useradd -m -u 1000 -s /bin/bash app

ENV project=attendee
ENV cwd=/$project
WORKDIR $cwd

COPY --chown=app:app --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=app:app . .

RUN mkdir -p "$cwd/staticfiles" && chown -R app:app "$cwd/staticfiles"

RUN mkdir -p /etc/opt/chrome/policies/managed \
  && ln -s /tmp/attendee-chrome-policies.json /etc/opt/chrome/policies/managed/attendee-chrome-policies.json

USER app

ENTRYPOINT ["/tini","--","/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
