document.addEventListener('DOMContentLoaded', function() {
    const button = document.getElementById('testButton');
    const message = document.getElementById('message');

    button.addEventListener('click', function() {
        message.textContent = '✓ JavaScript loaded successfully!';

        setTimeout(() => {
            message.textContent = '';
        }, 3000);
    });

    console.log('Horizon Static Middleware - JavaScript loaded');
});

