package com.example.emailtotrello.controller;

import com.example.emailtotrello.service.TrelloService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/webhook")
public class EmailWebhookController {

    @Autowired
    private TrelloService trelloService;

    @PostMapping
    public String receiveEmail(@RequestBody Map<String, Object> payload) {
        String subject = (String) payload.get("Subject");
        String body = (String) payload.get("TextBody");
        trelloService.createCard(subject, body);
        return "Card Created";
    }
}
