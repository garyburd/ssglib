// Gallery final-row sizing and lightbox. Each fenced-div gallery is a group;
// selecting an image opens that group's full-screen horizontal scroller.
//
// Each image's `lightbox-link` opens the full image without JavaScript. With
// JavaScript, a plain left-click opens its slide and displays its title.
document.addEventListener('DOMContentLoaded', () => {
    const galleries = [...document.querySelectorAll('.gallery')];

    // The CSS phantom absorbs final-row space with a 25% fallback. Size it so
    // those tiles match the preceding row. Re-running is safe because the
    // phantom cannot change tile breaks or the preceding row's height.
    function sizeLastRow(gallery) {
        const reset = () => {
            gallery.style.removeProperty('--phantom-basis');
            gallery.style.removeProperty('--phantom-grow');
        };
        // Group tiles by vertical offset.
        const rows = new Map();
        for (const link of gallery.querySelectorAll('a.lightbox-link')) {
            const top = link.offsetTop;
            if (!rows.has(top)) rows.set(top, []);
            rows.get(top).push(link);
        }
        // Let CSS handle one-row or hidden galleries.
        if (rows.size < 2) return reset();
        const tops = [...rows.keys()].sort((a, b) => a - b);
        const lastRow = rows.get(tops[tops.length - 1]);
        const height = rows.get(tops[tops.length - 2])[0].getBoundingClientRect().height;
        let sumRatios = 0;
        for (const link of lastRow) {
            const ratio = parseFloat(link.style.getPropertyValue('--aspect-ratio'));
            if (!ratio) return reset(); // keep CSS fallback for unknown ratios
            sumRatios += ratio;
        }
        // Give the phantom the space left after scaling tiles to the preceding
        // row. Include its leading gap and clamp full rows at zero.
        const gap = parseFloat(getComputedStyle(gallery).columnGap) || 0;
        const basis = gallery.clientWidth - sumRatios * height - gap * lastRow.length;
        gallery.style.setProperty('--phantom-basis', Math.max(basis, 0) + 'px');
        gallery.style.setProperty('--phantom-grow', '0');
    }

    galleries.forEach(sizeLastRow);

    let relayout = false;
    window.addEventListener('resize', () => {
        if (relayout) return;
        relayout = true;
        requestAnimationFrame(() => {
            relayout = false;
            galleries.forEach(sizeLastRow);
        });
    });

    galleries.forEach((gallery) => {
        const links = [...gallery.querySelectorAll('a.lightbox-link')];
        const images = links.map((link) => link.querySelector('img'));
        if (images.every((img) => img && img.src)) buildLightbox(links, images);
    });

    function createButton(parent, cls, innerText, ariaLabel) {
        const button = document.createElement('button');
        button.classList.add(cls);
        button.innerText = innerText;
        button.setAttribute('aria-label', ariaLabel);
        parent.appendChild(button);
        return button;
    }

    function buildLightbox(links, images) {
        const lightbox = document.createElement('dialog');
        lightbox.classList.add('lightbox');
        document.body.appendChild(lightbox);

        const prevBtn = createButton(lightbox, 'lightbox-prev', '❮', 'Previous image');
        const nextBtn = createButton(lightbox, 'lightbox-next', '❯', 'Next image');
        const closeBtn = createButton(lightbox, 'lightbox-close', '×', 'Close gallery');

        const scroller = document.createElement('div');
        scroller.classList.add('lightbox-scroller');
        lightbox.appendChild(scroller);

        const slides = [];
        let currentIndex = 0;
        const observerThreshold = 0.9;

        const observer = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting && entry.intersectionRatio >= observerThreshold) {
                    currentIndex = slides.indexOf(entry.target);
                    prevBtn.style.display = currentIndex <= 0 ? 'none' : '';
                    nextBtn.style.display = currentIndex >= slides.length - 1 ? 'none' : '';
                }
            });
        }, {
            root: scroller,
            threshold: observerThreshold,
        });

        images.forEach((image, index) => {

            // Open plain left-clicks in the lightbox; preserve other clicks.
            links[index].addEventListener('click', (e) => {
                if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
                e.preventDefault();
                lightbox.showModal();
                lightbox.focus();
                scroller.scrollTo({
                    left: scroller.clientWidth * index,
                    behavior: 'instant'
                });
            });

            const slide = document.createElement('div');
            slide.classList.add('lightbox-slide');
            scroller.appendChild(slide);
            observer.observe(slide);
            slides.push(slide);

            const lbImage = document.createElement('img');
            lbImage.loading = 'lazy';
            lbImage.src = image.src;
            lbImage.sizes = '100vw';
            if (image.srcset) lbImage.srcset = image.srcset;
            if (image.width) lbImage.width = image.width;
            if (image.height) lbImage.height = image.height;
            slide.appendChild(lbImage);

            // Show the title as the slide caption.
            if (image.title.trim()) {
                const caption = document.createElement('figcaption');
                caption.classList.add('lightbox-caption');
                caption.textContent = image.title;
                slide.appendChild(caption);
            }
        });

        function scrollSlides(delta, behavior = 'smooth') {
            const index = Math.min(Math.max(currentIndex + delta, 0), slides.length - 1);
            scroller.scrollTo({
                left: scroller.clientWidth * index,
                behavior: behavior,
            });
        }

        prevBtn.addEventListener('click', () => {
            scrollSlides(-1);
        });
        nextBtn.addEventListener('click', () => {
            scrollSlides(1);
        });
        closeBtn.addEventListener('click', () => {
            lightbox.close();
        });
        scroller.addEventListener('click', (e) => {
            const img = slides[currentIndex]?.querySelector('img');
            if (!img || !img.naturalWidth) return;
            // Find the visible image within the scale-down element.
            const r = img.getBoundingClientRect();
            const scale = Math.min(r.width / img.naturalWidth, r.height / img.naturalHeight, 1);
            const w = img.naturalWidth * scale;
            const h = img.naturalHeight * scale;
            const left = r.left + (r.width - w) / 2;
            const top = r.top + (r.height - h) / 2;
            if (e.clientX >= left && e.clientX <= left + w &&
                e.clientY >= top && e.clientY <= top + h) return;
            lightbox.close();
        });

        let cursorTimer;
        lightbox.addEventListener('mousemove', () => {
            lightbox.style.cursor = '';
            clearTimeout(cursorTimer);
            cursorTimer = setTimeout(() => { lightbox.style.cursor = 'none'; }, 2000);
        });
        lightbox.addEventListener('close', () => {
            clearTimeout(cursorTimer);
            lightbox.style.cursor = '';
        });

        let resizing = false;
        window.addEventListener('resize', () => {
            if (!lightbox.open) return;
            if (!resizing) {
                resizing = true;
                requestAnimationFrame(() => {
                    resizing = false;
                    // Force Safari to reevaluate `srcset`.
                    lightbox.querySelectorAll('img[sizes="100vw"]').forEach((image) => {
                        image.sizes = '101vw';
                        image.sizes = '100vw';
                    });
                    scrollSlides(0, 'instant');
                });
            }
        });

        lightbox.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowLeft') {
                scrollSlides(-1);
                e.preventDefault();
            } else if (e.key === 'ArrowRight') {
                scrollSlides(1);
                e.preventDefault();
            }
        });
    }
});
