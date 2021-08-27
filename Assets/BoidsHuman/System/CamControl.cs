using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CamControl : MonoBehaviour
{
    public float speed = 10.0f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKey (KeyCode.LeftArrow)) {
            this.transform.Translate (speed*Time.deltaTime*-0.1f,0.0f,0.0f);
        }
        // 右に移動
        if (Input.GetKey (KeyCode.RightArrow)) {
            this.transform.Translate (speed*Time.deltaTime*0.1f,0.0f,0.0f);
        }
        // 前に移動
        if (Input.GetKey (KeyCode.UpArrow)) {
            this.transform.Translate (0.0f,speed*Time.deltaTime*0.1f, 0.0f);
        }
        // 後ろに移動
        if (Input.GetKey (KeyCode.DownArrow)) {
            this.transform.Translate (0.0f,speed*Time.deltaTime*-0.1f, 0.0f);
        }
    }
}
