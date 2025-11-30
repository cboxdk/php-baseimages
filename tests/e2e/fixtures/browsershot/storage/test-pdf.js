const puppeteer = require('puppeteer-core');

(async () => {
    const browser = await puppeteer.launch({
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium-browser',
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
        ]
    });

    const page = await browser.newPage();
    await page.setContent('<h1>PHPeek PDF Test</h1><p>Generated at: ' + new Date().toISOString() + '</p>');
    await page.pdf({ path: process.argv[2], format: 'A4' });
    await browser.close();

    console.log('PDF generated successfully');
})();