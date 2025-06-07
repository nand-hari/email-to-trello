package com.example.emailtotrello.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Service
public class TrelloService {

    @Value("${trello.key}")
    private String trelloKey;

    @Value("${trello.token}")
    private String trelloToken;

    @Value("${trello.boardId}")
    private String boardId;

    @Value("${trello.listId}")
    private String listId;

    public void createCard(String name, String desc) {
        String url = "https://api.trello.com/1/cards";

        Map<String, String> params = new HashMap<>();
        params.put("name", name);
        params.put("desc", desc);
        params.put("idList", listId);
        params.put("key", trelloKey);
        params.put("token", trelloToken);

        RestTemplate restTemplate = new RestTemplate();
        restTemplate.postForLocation(url + "?name={name}&desc={desc}&idList={idList}&key={key}&token={token}", params);
    }
}
