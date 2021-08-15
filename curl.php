<?php

$username = 'ysmtegsr';
$domain   = 'https://zenn.dev';
$endpoint = $domain . '/api/articles?username=' . $username . '&count=10&order=latest';


date_default_timezone_set('Asia/Tokyo');
$conn = curl_init();

curl_setopt($conn, CURLOPT_URL, $endpoint);
curl_setopt($conn, CURLOPT_RETURNTRANSFER, true);
$res = curl_exec($conn);
curl_close($conn);

$articles = [];

foreach (json_decode($res, true)['articles'] as $article) {
    $articles[] = [
        'emoji'        => $article['emoji'],
        'title'        => '[' . $article['title'] . '](' . $domain  . '/'. $username . '/articles/' . $article['slug'] . ')',
        'title'        => '[' . $article['title'] . '](' . implode('/', [ $domain, $username, 'articles', $article['slug'] ]) . ')',
        'liked_count'  => $article['liked_count'],
        'topics'       => implode(' , ', array_map(fn($value): string => '`' . $value['display_name'] . '`', $article['topics'])),
        'published_at' => date('Y-m-d H:i', strtotime($article['published_at'])),
    ];
}

$md = "\n| | Title | Liked Count | Topics | Date\n --- | --- | --- | --- | ---\n";

foreach ($articles as $article) {
    $md .= implode(" | ", $article) . "\n";
}

file_put_contents(
    'README.md',
    preg_replace(
        '/<!-- Start latest articles -->.*<!-- End latest articles -->/s',
        "<!-- Start latest articles -->\n${md}<!-- End latest articles -->",
        file_get_contents('README.md')
    )
);
