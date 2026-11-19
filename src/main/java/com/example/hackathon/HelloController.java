package com.example.hackathon;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
public class HelloController {

    // 기존 GET API
    @GetMapping("/api/hello")
    public Map<String, String> hello() {
        return Map.of("message", "안녕하세요!");
    }

    // 새로 추가한 POST API
    @PostMapping("/api/hello")
    public ResponseEntity<Map<String, String>> greet(
            @RequestBody HelloRequest request) {

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of(
                        "message", request.name() + "님, 반갑습니다!"
                ));
    }

    public record HelloRequest(String name) {}
}